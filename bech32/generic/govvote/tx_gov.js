// this is coded tx on .../tx?hash0x... at the end there is coded tx, the nodejs script decodes it then also translate the binary data
// this is version 2
const { fromBase64 } = require("@cosmjs/encoding");
const { decodeTxRaw } = require("@cosmjs/proto-signing");
const { MsgVote } = require("cosmjs-types/cosmos/gov/v1/tx");

// Base64 encoded transaction
const txBase64 = "Ck8KTQoWL2Nvc21vcy5nb3YudjEuTXNnVm90ZRIzCAISLXdhcmRlbjEzYTc3OWx6dXdleTJkdGh3bG42MmttempoZTRtYXk4NmF1NGc2bhgBEnsKWQpPCigvZXRoZXJtaW50LmNyeXB0by52MS5ldGhzZWNwMjU2azEuUHViS2V5EiMKIQNdMvi+/VOkQGLeiD+12gGMmu3FK7Uu/kXvA1uDvk0x0xIECgIIARgBEh4KGAoFYXdhcmQSDzI1MDAwMDAwMDAwMDAwMBDBoQgaQW/Hyv86Fqvg5TQjZQ3I8wRuwbspnqP4OhtQIcU9T99baEUo/QMOizVSV40ADQzqjF0GlsfaqymGARBxYRakeNMA";

// Step 1: Decode the Base64 transaction into binary
const txBytes = fromBase64(txBase64);

// Step 2: Decode the raw transaction bytes
const decodedTx = decodeTxRaw(txBytes);

// Step 3: Decode individual fields like message values

// Helper function to decode the vote message
function decodeVoteMessage(messageBytes) {
    const voteMessage = MsgVote.decode(messageBytes);
    return {
        voter: voteMessage.voter,
        proposalId: voteMessage.proposalId,
        option: voteMessage.option, // Voting options: 1 (Yes), 2 (Abstain), 3 (No), 4 (No with Veto)
    };
}

// Step 4: Process decoded transaction data for human readability
const signerInfo = decodedTx.authInfo.signerInfos[0];
const fee = decodedTx.authInfo.fee;

const decodedTransaction = {
    sequence: signerInfo.sequence,
    fee: {
        amount: fee.amount[0].amount,
        denom: fee.amount[0].denom,
        gasLimit: fee.gasLimit,
    },
    messages: decodedTx.body.messages.map(msg => {
        if (msg.typeUrl === "/cosmos.gov.v1.MsgVote") {
            return decodeVoteMessage(msg.value);
        }
        return { unknownMessage: msg.typeUrl };
    }),
    signatures: decodedTx.signatures.map(sig => Buffer.from(sig).toString('hex')),
};

// Step 5: Custom BigInt handling for JSON.stringify
function bigintReplacer(key, value) {
    return typeof value === 'bigint' ? value.toString() : value;
}

// Step 6: Output the decoded transaction in human-readable format
console.log("Decoded Transaction:", JSON.stringify(decodedTransaction, bigintReplacer, 2));
