// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {IExtendedResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IExtendedResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {VOTES_HASH} from "./Constants.sol";

contract FakeVotesResolver is IExtendedResolver {
    function supportsInterface(bytes4 x) external pure returns (bool) {
        return
            x == type(IERC165).interfaceId ||
            x == type(IExtendedResolver).interfaceId;
    }

    function resolve(
        bytes calldata dns,
        bytes calldata data
    ) external view returns (bytes memory) {
        uint256 balance = uint256(keccak256(abi.encode(dns, block.timestamp))) %
            block.number;
        if (bytes4(data) == ITextResolver.text.selector) {
            (, string memory key) = abi.decode(data[4:], (bytes32, string));
            if (keccak256(bytes(key)) == VOTES_HASH) {
                return abi.encode(Strings.toString(balance));
            }
        } else if (bytes4(data) == IAddressResolver.addr.selector) {
            uint256 coinType = abi.decode(data[36:], (uint256));
            if (coinType == uint256(VOTES_HASH)) {
                return abi.encode(abi.encode(balance));
            }
		}
        return new bytes(64);
    }
}
