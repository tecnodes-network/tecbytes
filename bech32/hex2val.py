import binascii
from bech32 import bech32_encode, convertbits

def convert_hex_to_bech32_address(hex_address, prefix):
    # Convert the hex address to bytes
    address_bytes = bytes.fromhex(hex_address)

    # Convert bytes to 5-bit words required for Bech32 encoding
    five_bit_words = convertbits(address_bytes, 8, 5, pad=True)
    if five_bit_words is None:
        raise ValueError("Error converting bytes to 5-bit words")

    # Bech32 encode the data with the specified prefix
    bech32_address = bech32_encode(prefix, five_bit_words)

    return bech32_address

# Example usage
hex_address = 'BAED8E3FAD9FD20457EA2AD53A631AFAA6477F3A'

# Convert to wallet address
wallet_prefix = 'story'  # Replace with your blockchain's wallet prefix
wallet_address = convert_hex_to_bech32_address(hex_address, wallet_prefix)
print('Wallet Address:', wallet_address)

# Convert to validator operator address
valoper_prefix = 'storyvaloper'  # Replace with your blockchain's valoper prefix
valoper_address = convert_hex_to_bech32_address(hex_address, valoper_prefix)
print('Validator Operator Address:', valoper_address)

# Convert to validator consensus address
valcons_prefix = 'storyvalcons'  # Replace with your blockchain's valcons prefix
valcons_address = convert_hex_to_bech32_address(hex_address, valcons_prefix)
print('Validator Consensus Address:', valcons_address)
