"""Headquarters administration API routers."""

from . import approvals, branches, contracts, inquiries, inventory, members, orders, reviews, sales

routers = (orders.router, inventory.router, approvals.router, sales.router, branches.router, contracts.router,
           members.router, reviews.router, inquiries.router)
