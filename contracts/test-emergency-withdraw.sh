#!/bin/bash

# Test emergency withdraw function
# Note: Requires MAINNET_RPC_URL to be set in contracts/.env

if [ ! -f contracts/.env ]; then
    echo "⚠️  No .env file found. Tests will use public RPC (may be rate limited)"
    echo ""
    echo "To run with your own RPC:"
    echo "  1. Copy: cp contracts/.env.example contracts/.env"
    echo "  2. Add:  MAINNET_RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY"
    echo ""
fi

cd contracts

echo "🧪 Running EmergencyWithdraw Tests..."
echo "======================================"
echo ""

forge test --match-contract EmergencyWithdrawTest -vvv

echo ""
echo "✅ Test run complete!"
