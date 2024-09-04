pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

interface IOgSpaceship is IERC721 {

    function transferOwnership(address newOwner) external;

    function mint(address to, uint256 tokenId, string memory uri) external;

    function burn(uint256 tokenId) external;

    function bulkBurn(uint256[] memory tokenIds) external;

    function ownerOf(uint256 tokenId) external view returns (address owner);

    function tokenURI(uint256 tokenId) external view returns (string memory);
}
