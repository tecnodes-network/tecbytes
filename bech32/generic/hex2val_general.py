import hashlib
from bech32 import bech32_encode, convertbits

def address_from_pubkey(pubkey_hex, prefix):
    # Convert the public key from hex to bytes
    pubkey_bytes = bytes.fromhex(pubkey_hex)
    
    # Perform SHA256 hashing on the public key
    sha256_digest = hashlib.sha256(pubkey_bytes).digest()

    # Perform RIPEMD160 hashing on the SHA256 digest
    ripemd160_digest = hashlib.new('ripemd160', sha256_digest).digest()

    # Convert to 5-bit words
    five_bit_words = convertbits(ripemd160_digest, 8, 5, pad=True)
    if five_bit_words is None:
        raise ValueError("Error converting bytes to 5-bit words")

    # Bech32 encode with the specified prefix
    bech32_address = bech32_encode(prefix, five_bit_words)
    return bech32_address

def consensus_address_from_pubkey(consensus_pubkey_hex, prefix):
    # Convert the consensus public key from hex to bytes
    pubkey_bytes = bytes.fromhex(consensus_pubkey_hex)

    # Perform SHA256 hashing on the consensus public key
    sha256_digest = hashlib.sha256(pubkey_bytes).digest()

    # Perform RIPEMD160 hashing on the SHA256 digest
    ripemd160_digest = hashlib.new('ripemd160', sha256_digest).digest()

    # Convert to 5-bit words
    five_bit_words = convertbits(ripemd160_digest, 8, 5, pad=True)
    if five_bit_words is None:
        raise ValueError("Error converting bytes to 5-bit words")

    # Bech32 encode with the specified prefix
    bech32_address = bech32_encode(prefix, five_bit_words)
    return bech32_address

# Example usage

# Replace these with your actual public keys in hex format
account_pubkey_hex = '...'          # Account public key in hex
consensus_pubkey_hex = '...'        # Consensus public key in hex

# Generate wallet address (account address)
wallet_prefix = 'quick'
wallet_address = address_from_pubkey(account_pubkey_hex, wallet_prefix)
print('Wallet Address:', wallet_address)

# Generate validator operator address
valoper_prefix = 'quickvaloper'
valoper_address = address_from_pubkey(account_pubkey_hex, valoper_prefix)
print('Validator Operator Address:', valoper_address)

# Generate validator consensus address
valcons_prefix = 'quickvalcons'
valcons_address = consensus_address_from_pubkey(consensus_pubkey_hex, valcons_prefix)
print('Validator Consensus Address:', valcons_address)

# this one need public keys ad hex
