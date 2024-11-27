// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {BytesUtils} from "@ensdomains/ens-contracts/contracts/utils/BytesUtils.sol";

interface IHook {
    function hook(
        bytes calldata encodedFunction,
        address resolver,
        uint256 chainId
    ) external view;
}

error WrongResolver(address expected, address current);
error WrongChain(uint256 expected, uint256 current);

library HookVerifier {
    function verify(
        bytes memory data,
        address currentResolver
    ) external view returns (bytes memory) {
        if (bytes4(data) == IHook.hook.selector) {
            (bytes memory v, address resolver, uint256 chain) = abi.decode(
                BytesUtils.substring(data, 4, data.length - 4),
                (bytes, address, uint256)
            );
            if (resolver != currentResolver) {
                revert WrongResolver(resolver, currentResolver);
            }
            uint256 currentChain;
            assembly {
                currentChain := chainid()
            }
            if (chain != currentChain) {
                revert WrongChain(chain, currentChain);
            }
            data = v;
        }
        return data;
    }
}
