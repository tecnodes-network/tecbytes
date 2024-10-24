// version one only decodes and shows binary data

const { fromBase64 } = require("@cosmjs/encoding");
const { decodeTxRaw } = require("@cosmjs/proto-signing");

// Base64 encoded transaction
const txBase64 = "Ck8KTQoWL2Nvc21vcy5nb3YudjEuTXNnVm90ZRIzCAISLXdhcmRlbjEzYTc3OWx6dXdleTJkdGh3bG42MmttempoZTRtYXk4NmF1NGc2bhgBEnsKW>

// Step 1: Decode the Base64 transaction into binary
const txBytes = fromBase64(txBase64);

// Step 2: Decode the raw transaction bytes
const decodedTx = decodeTxRaw(txBytes);

// Step 3: Custom BigInt handling for JSON.stringify
function bigintReplacer(key, value) {
    return typeof value === 'bigint' ? value.toString() : value;
}

// Step 4: Output the decoded transaction in human-readable format
console.log("Decoded Transaction:", JSON.stringify(decodedTx, bigintReplacer, 2));
