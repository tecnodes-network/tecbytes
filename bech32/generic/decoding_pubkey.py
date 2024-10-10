def decode_amino_pubkey(amino_pubkey_hex):
    amino_bytes = bytes.fromhex(amino_pubkey_hex)
    # Remove Amino prefix (first 5 bytes for ed25519 keys)
    # ed25519 Amino prefix: 0x1624DE6420
    if amino_bytes.startswith(b'\x16\x24\xDE\x64\x20'):
        pubkey_bytes = amino_bytes[5:]
        return pubkey_bytes
    else:
        raise ValueError("Unknown Amino prefix or public key type")

# Example usage
consensus_pubkey_hex = '1624DE6420...'  # Amino-encoded ed25519 pubkey in hex
consensus_pubkey_bytes = decode_amino_pubkey(consensus_pubkey_hex)
