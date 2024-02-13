#!/bin/bash

# --- Initial Variables ---
binary="dymd"       
rpc="http://localhost:26657"
chain_id="dymension_1100-1" # Ask user to provide
validator_address=""
wallet_address=
wallet_name=""
denomination="adym" 
denomination_exponent=18
sleep_interval=43200        
threshold=9000000000000000000  # 9 dym 
reserve_amount=1000000000000000000 # 1 dym
explorer=https://dymension.explorers.guru 

# Retrieves balance, rewards, and commission, converts to 'dym' format 
check_balance() {
    balance=$($binary query bank balances $wallet_address --node $rpc -o json | jq -r '.balances[0].amount')
    available_rewards=$($binary query distribution rewards $wallet_address $validator_address --node $rpc -o json | jq -r '.rewards[0].amount')
    available_commission=$($binary query distribution commission $validator_address --node $rpc -o json | jq -r '.commission[0].amount')

    # Calculate amounts in 'dym' format
    balance_dym=$(bc <<< "scale=9; $balance / 10^$denomination_exponent") 
    rewards_dym=$(bc <<< "scale=9; $available_rewards / 10^$denomination_exponent")
    commission_dym=$(bc <<< "scale=9; $available_commission / 10^$denomination_exponent")

    # Sum up for comparison
    combined_amount_dym=$(bc <<< "$balance_dym + $rewards_dym + $commission_dym")

    echo "Available Rewards: $rewards_dym dym"
    echo "Available Commission: $commission_dym dym"
    echo "Total (Balance + Rewards): $combined_amount_dym dym"
}

# Withdraws available rewards (updated password handling)
withdraw_rewards() {
    tx_response=$($binary tx distribution withdraw-rewards $validator_address --from $wallet_name --commission --node $rpc --chain-id=$chain_id --yes --gas-prices 0adym --gas auto --gas-adjustment=1.5 -o json <<< $wallet_pass)
    tx_hash=$(echo $tx_response | jq -r '.txhash') # Extract tx hash

    echo "Withdraw Successfull - Hash: $explorer/transaction/$tx_hash" 

    # sleep until tx get through
    echo "Sleeping 60 sec till tx go through"
    sleep 60

    # Add error checking on tx_response 
}

# Delegates available amount (maintains 'adym' for transaction)
delegate() {
    #delegation_amount=$(bc <<< "$balance + $available_rewards + $available_commission - $reserve_amount")
    balance=$($binary query bank balances $wallet_address --node $rpc -o json | jq -r '.balances[0].amount')
    delegation_amount=$(bc <<< "$balance - $reserve_amount")

    # Check before delegating 
    if [ "$(bc <<< "$delegation_amount > 0")" -eq 1 ]; then 
        # Fetch the correct account sequence number
        echo "Going to delegate: $delegation_amount"        
        account_sequence=$($binary query auth account $wallet_address --node $rpc -o json | jq -r '.base_vesting_account.base_account.sequence')

        tx_response=$($binary tx staking delegate $validator_address ${delegation_amount}adym --from $wallet_name --node $rpc --chain-id=$chain_id --yes --gas-prices 0adym --gas auto --gas-adjustment=1.5 --sequence $account_sequence -o json <<< $wallet_pass)

        tx_hash=$(echo $tx_response | jq -r '.txhash') # Extract tx hash
        echo "Delegation Successfull - Hash: $explorer/transaction/$tx_hash"
    else 
        echo "Not enough to delegate after considering reserve amount."
    fi
}


# --- Main Logic ---

# Get wallet password on first run
read -sp "Enter wallet password: " wallet_pass
echo "" 

while true; do
    check_balance

    # Calculate combined total in smallest denomination (adym) for threshold check    
    combined_amount=$(bc <<< "$balance + $available_rewards + $available_commission")

    if [ "$(bc <<< "$combined_amount > $threshold")" -eq 1 ]; then
        combined_amount_dym=$(bc <<< "scale=9; $combined_amount / 10^$denomination_exponent")
        echo "The total amount is above the threshold: $combined_amount_dym"
        echo "Going to withdraw + delegate..."
        withdraw_rewards
        delegate # Call delegate to execute now that the rewards were received
    else 
        echo "Reward + Commission below threshold. Skipping delegation."
    fi

    echo "Main script is going to sleep for 12h"
    sleep $sleep_interval 
done 
