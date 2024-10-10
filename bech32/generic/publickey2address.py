# Sample public keys in HEX (replace with actual keys)
account_pubkey_hex = '029abc...def'         # Example compressed secp256k1 public key
consensus_pubkey_hex = 'eb5ae98721...'      # Example Amino-encoded ed25519 public key

# Generate wallet address
wallet_address = address_from_pubkey(account_pubkey_hex, 'quick')
print('Wallet Address:', wallet_address)

# Generate validator operator address
valoper_address = address_from_pubkey(account_pubkey_hex, 'quickvaloper')
print('Validator Operator Address:', valoper_address)

# Generate validator consensus address
valcons_address = consensus_address_from_pubkey(consensus_pubkey_hex, 'quickvalcons')
print('Validator Consensus Address:', valcons_address)
