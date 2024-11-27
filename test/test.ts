import { Foundry } from "@adraffy/blocksmith";
import {
	dnsEncode,
	namehash,
	solidityPackedKeccak256,
	Interface,
	type BigNumberish,
	type BytesLike,
} from "ethers";

type HexString = string;

const foundry = await Foundry.launch({
	fork: `https://rpc.ankr.com/eth`,
});

const ENS_REGISTRY = "0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e";
const ENS_ERC20 = "0xc18360217d8f7ab5e7c516566761ea12ce7f9d72";
const BASENAME = "votes.eth";

const HOOK_ABI = new Interface([
	`function hook(bytes encodedFunction, address resolver, uint256 chainId) view`,
]);
const RESOLVER_ABI = new Interface([
	`function text(bytes32, string) external view returns (string)`,
	`function addr(bytes32, uint256) external view returns (bytes)`,
]);

const HookVerifier = await foundry.deploy({ file: "HookVerifier" });
const FakeVotesResolver = await foundry.deploy({ file: "FakeVotesResolver" });
const ENSVotesResolver = await foundry.deploy({
	file: "ENSVotesResolver",
	args: [ENS_REGISTRY, ENS_ERC20],
});
const UR = await foundry.deploy({
	file: "UR",
	args: [ENS_REGISTRY, ["https://ccip-v2.ens.xyz"]],
	libs: { HookVerifier },
	abis: [HookVerifier],
});

await test("premm.eth");
await test("nick.eth");

await foundry.shutdown();

async function test(name: string) {
	const voterName = await generateName(name);
	const calldata = RESOLVER_ABI.encodeFunctionData("text", [
		namehash(voterName),
		"ens.votes",
	]);
	const hookdata = wrapHook(calldata, ENSVotesResolver.target, 1);
	console.log({ name, voterName, calldata, hookdata });
	await hijackResolver(BASENAME, ENSVotesResolver.target);
	console.log(`call`, await resolveVotes(voterName, calldata));
	console.log(`hook`, await resolveVotes(voterName, hookdata));
	console.log(`hook w/wrong chain`, await resolveVotes(voterName, wrapHook(calldata, ENSVotesResolver.target, 2)));
	await hijackResolver(BASENAME, FakeVotesResolver.target);
	console.log(`call w/wrong resolver`, await resolveVotes(voterName, calldata));
	console.log(`hook w/wrong resolver`, await resolveVotes(voterName, hookdata));
}

function wrapHook(data: BytesLike, resolver: HexString, chain: BigNumberish) {
	return HOOK_ABI.encodeFunctionData("hook", [data, resolver, chain]);
}

async function generateName(name: string) {
	const address = await foundry.provider.resolveName(name);
	if (!address) throw new Error(`no address for "${name}"`);
	return `${address.slice(2).toLowerCase()}.${BASENAME}`;
}

async function resolveVotes(name: string, data: HexString) {
	try {
		const [lookup, [[bits, encoded]]] = await UR.resolve(
			dnsEncode(name, 255),
			[data],
			[],
			{
				enableCcipRead: true,
			}
		);
		if (bits & 1n) {
			const error = UR.interface.parseError(encoded);
			if (!error) throw new Error(`unknown error: ${encoded}`);
			throw new Error(error.signature); //`${error.signature}: ${error.args}`);
		}
		const [votes] = RESOLVER_ABI.decodeFunctionResult("text", encoded);
		return votes;
	} catch (err) {
		return String(err);
	}
}

async function hijackResolver(name: string, resolver: HexString) {
	await foundry.setStorageValue(
		ENS_REGISTRY,
		BigInt(
			solidityPackedKeccak256(["bytes32", "uint256"], [namehash(name), 0])
		) + 1n,
		resolver
	);
	console.log(`Set ${name} to ${resolver}`);
}
