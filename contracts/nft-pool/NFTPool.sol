// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "./RoleManager.sol";

contract NFTPool is RoleManager, IERC721Receiver {
    using Address for address;

    /********************
     * Global Variables *
     ********************/

    string public constant VERSION = "v1.0.1";
    bytes4 public constant ERC721_SAFE_TRANSFER_FROM_SELECTOR = 0x42842e0e; // bytes4(keccak256("safeTransferFrom(address,address,uint256)"));

    /**********
     * Events *
     **********/

    event PoolTransfer(
        IERC721 indexed token,
        address indexed to,
        uint256 tokenId
    );

    /**********
     * Errors *
     **********/

    error ErrUnexpectedERC721Response();

    /***************
     * Constructor *
     ***************/

    constructor(address newAdmin, address newWorker)
        RoleManager(newAdmin, newWorker)
    {}

    /*****************************
     * External/Public Functions *
     *****************************/

    /**
     * @dev Transfer a erc721 token from this contract to the specified address.
     * @notice This function can only be called by the worker.
     * @param token - the contract address of the erc721 token.
     * @param to - the address to transfer the token to.
     * @param tokenId - the id of the token to transfer.
     */
    function transferERC721(
        IERC721 token,
        address to,
        uint256 tokenId
    ) external onlyWorker {
        emit PoolTransfer(token, to, tokenId);
        _callERC721SafeTransferFrom(token, address(this), to, tokenId);
    }

    /**********************
     * Internal Functions *
     **********************/

    /**
     * @dev Call the `safeTransferFrom` function by the `Address.functionCall` to have better error handling.
     */
    function _callERC721SafeTransferFrom(
        IERC721 token,
        address from,
        address to,
        uint256 tokenId
    ) internal {
        bytes memory data = abi.encodeWithSelector(
            ERC721_SAFE_TRANSFER_FROM_SELECTOR,
            from,
            to,
            tokenId
        );

        bytes memory returndata = address(token).functionCall(
            data,
            "NFTPool: ERC721 safeTransferFrom failed"
        );

        if (returndata.length != 0) {
            revert ErrUnexpectedERC721Response();
        }
    }

    /********
     * Misc *
     ********/

    /**
     * @dev Implementation of {IERC721Receiver-onERC721Received}.
     */
    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}
