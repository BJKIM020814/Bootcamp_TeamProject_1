require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require 'time'

# This tool only targets the already connected development database.
PROJECT = 'shoe-20260930'
ROOT = "projects/#{PROJECT}/databases/(default)/documents"
BASE = "https://firestore.googleapis.com/v1/#{ROOT}"
BACKUPS = File.join(__dir__, 'backups')

def request(method, url, body = nil)
  tokens = JSON.parse(File.read(File.expand_path('~/.config/configstore/firebase-tools.json'))).fetch('tokens')
  uri = URI(url)
  req = method == :get ? Net::HTTP::Get.new(uri) : Net::HTTP::Post.new(uri)
  req['Authorization'] = "Bearer #{tokens.fetch('access_token')}"
  req['Content-Type'] = 'application/json'
  req.body = JSON.generate(body) if body
  res = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 30) { |http| http.request(req) }
  abort("HTTP #{res.code}; refresh CLI login with firebase firestore:databases:list --project #{PROJECT}") unless res.is_a?(Net::HTTPSuccess)
  JSON.parse(res.body)
end

def collections(parent = BASE)
  result = []
  page = nil
  loop do
    body = { 'pageSize' => 100 }
    body['pageToken'] = page if page
    data = request(:post, "#{parent}:listCollectionIds", body)
    result.concat(data.fetch('collectionIds', []))
    page = data['nextPageToken']
    break unless page
  end
  result.sort
end

def documents(collection)
  result = []
  page = nil
  loop do
    params = { pageSize: 100 }
    params[:pageToken] = page if page
    data = request(:get, "#{BASE}/#{collection}?#{URI.encode_www_form(params)}")
    result.concat(data.fetch('documents', []))
    page = data['nextPageToken']
    break unless page
  end
  result
end

def encode(key, value)
  case value
  when true, false then { 'booleanValue' => value }
  when Integer then { 'integerValue' => value.to_s }
  when String
    key.end_with?('At') ? { 'timestampValue' => value } : { 'stringValue' => value }
  else abort("Unsupported seed type for #{key}")
  end
end

mode = ARGV.fetch(0, '--plan')
abort('Use --plan, --apply, or --verify') unless %w[--plan --apply --verify].include?(mode)
records = JSON.parse(File.read(File.join(__dir__, 'erd_seed.json')))
expected = records.to_h do |r|
  ["#{ROOT}/#{r.fetch('collection')}/#{r.fetch('id')}",
   r.fetch('fields').to_h { |key, value| [key, encode(key, value)] }]
end
target_ids = records.map { |r| r.fetch('collection') }.sort
abort('Expected exactly 13 distinct ERD collections') unless target_ids.uniq.length == 13
ids = collections
current = ids.flat_map { |id| documents(id) }
by_name = current.to_h { |doc| [doc.fetch('name'), doc] }

if mode == '--verify'
  abort("Collection mismatch: #{ids}") unless ids == target_ids
  abort('Unexpected documents') unless by_name.keys.sort == expected.keys.sort
  expected.each do |name, fields|
    abort("Field mismatch: #{name}") unless by_name.fetch(name).fetch('fields') == fields
  end
  puts "Verified #{ids.length} collections, #{current.length} documents and all fields."
  puts ids.join(', ')
  exit
end

# Only these two previously supplied synthetic fixtures may be removed.
removable = {
  "#{ROOT}/login/LOGIN-001" => {
    'email' => { 'stringValue' => 'user@example.com' },
    'password' => { 'stringValue' => 'TEST_ONLY_password_001' }
  },
  "#{ROOT}/changepassword/PWD-001" => {
    'email' => { 'stringValue' => 'user@example.com' },
    'changedPassword' => { 'stringValue' => 'TEST_ONLY_changed_002' }
  }
}
abort('Unexpected collections: inspect before migrating') unless (ids - target_ids - %w[login changepassword]).empty?
abort('Unexpected documents: inspect before migrating') unless (by_name.keys - expected.keys - removable.keys).empty?
current.each do |doc|
  abort("Nested collection needs separate review: #{doc.fetch('name')}") unless collections("https://firestore.googleapis.com/v1/#{doc.fetch('name')}").empty?
end

writes = []
expected.each do |name, fields|
  previous = by_name[name]
  if previous
    actual = previous.fetch('fields', {})
    # Preserve existing values: only add missing ERD fields to known fixtures.
    abort("Existing values differ: #{name}") unless actual.all? { |key, value| fields[key] == value }
    additions = fields.keys - actual.keys
    next if additions.empty?
    writes << {
      'update' => { 'name' => name, 'fields' => fields.select { |key, _| additions.include?(key) } },
      'updateMask' => { 'fieldPaths' => additions },
      'currentDocument' => { 'updateTime' => previous.fetch('updateTime') }
    }
    puts "ADD FIELDS #{name.split('/documents/').last}: #{additions.join(', ')}"
  else
    writes << { 'update' => { 'name' => name, 'fields' => fields }, 'currentDocument' => { 'exists' => false } }
    puts "CREATE #{name.split('/documents/').last}"
  end
end
removable.each do |name, fields|
  previous = by_name[name]
  next unless previous
  abort("Not the known test fixture: #{name}") unless previous.fetch('fields') == fields
  writes << { 'delete' => name, 'currentDocument' => { 'updateTime' => previous.fetch('updateTime') } }
  puts "DELETE TEST FIXTURE #{name.split('/documents/').last}"
end
puts "#{writes.length} planned writes; all pre-existing retained values preserved."
exit if mode == '--plan' || writes.empty?

release = request(:get, "https://firebaserules.googleapis.com/v1/projects/#{PROJECT}/releases/cloud.firestore")
ruleset = request(:get, "https://firebaserules.googleapis.com/v1/#{release.fetch('rulesetName')}")
FileUtils.mkdir_p(BACKUPS, mode: 0700)
backup = File.join(BACKUPS, "before-erd-#{Time.now.utc.strftime('%Y%m%dT%H%M%S%6N')}.json")
payload = { 'project' => PROJECT, 'database' => '(default)', 'documents' => current, 'ruleset' => ruleset, 'writes' => writes }
File.open(backup, File::WRONLY | File::CREAT | File::EXCL, 0600) { |file| file.write(JSON.pretty_generate(payload)) }
abort('Backup verification failed') unless JSON.parse(File.read(backup)) == payload
puts "Backup saved: #{backup}"
request(:post, "#{BASE}:commit", { 'writes' => writes })
puts "Committed #{writes.length} writes atomically. Run --verify to re-read every document."
