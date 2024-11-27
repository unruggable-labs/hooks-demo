// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import {IAddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {BytesUtils} from "@ensdomains/ens-contracts/contracts/utils/BytesUtils.sol";
import {HexUtils} from "@ensdomains/ens-contracts/contracts/utils/HexUtils.sol";
import {VOTES_HASH} from "./Constants.sol";
import "forge-std/console2.sol";

error Unreachable(bytes dns);

interface ENSToken {
	function getVotes(address) external view returns (uint256);
	function decimals() external view returns (uint256);
}

contract ENSVotesResolver is IExtendedResolver {
    ENS immutable _ens;
    ENSToken immutable _token;

    constructor(ENS ens, ENSToken token) {
        _ens = ens;
        _token = token;
    }

    function supportsInterface(bytes4 x) external pure returns (bool) {
        return
            x == type(IERC165).interfaceId ||
            x == type(IExtendedResolver).interfaceId;
    }

    function resolve(
        bytes calldata dns,
        bytes calldata data
    ) external view returns (bytes memory) {
        (, uint256 offset) = _findSelf(dns);
        if (offset > 0) {
			(address holder, bool ok) = HexUtils.hexToAddress(
                dns,
                1,
                offset
            );
            if (!ok || offset != 41) revert Unreachable(dns);
            uint256 balance = _token.getVotes(holder) / 10**_token.decimals();
            if (bytes4(data) == ITextResolver.text.selector) {
                (, string memory key) = abi.decode(data[4:], (bytes32, string));
                bytes32 hash = keccak256(bytes(key));
                if (hash == VOTES_HASH) {
                    return abi.encode(Strings.toString(balance));
                } else if (hash == keccak256(bytes("avatar"))) {
                    return
                        abi.encode(
                            "https://tokens-data.1inch.io/images/0xc18360217d8f7ab5e7c516566761ea12ce7f9d72.png"
                        );
                }
            } else if (bytes4(data) == IAddressResolver.addr.selector) {
                uint256 coinType = abi.decode(data[36:], (uint256));
                if (coinType == 60) {
                    return abi.encode(abi.encodePacked(holder));
                } else if (coinType == uint256(VOTES_HASH)) {
                    return abi.encode(abi.encode(balance));
                }
            } else if (bytes4(data) == IAddrResolver.addr.selector) {
				return abi.encode(holder);
			}
        }
        return new bytes(64);
    }

    function _findSelf(
        bytes memory dns
    ) internal view returns (bytes32 node, uint256 offset) {
        unchecked {
            while (true) {
                node = BytesUtils.namehash(dns, offset);
                if (_ens.resolver(node) == address(this)) break;
                uint256 size = uint256(uint8(dns[offset]));
                if (size == 0) revert Unreachable(dns);
                offset += 1 + size;
            }
        }
    }
}
