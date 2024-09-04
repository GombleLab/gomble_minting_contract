// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface ISpaceKid {
    function getTokensByOwner(address owner) external view returns (uint256[] memory);

    function mint(address to, uint256 tokenId) external;

    function tokenURI(uint256 tokenId) external view returns (string memory);

    function totalSupply() external view virtual returns (uint256);
}
