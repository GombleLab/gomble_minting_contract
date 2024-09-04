pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/IOgSpaceship.sol";

contract SpaceshipLock is OwnableUpgradeable, IERC721Receiver {
    using Strings for uint256;

    IOgSpaceship public ogSpaceshipDebut;
    IOgSpaceship public ogSpaceshipClimax;
    string private climaxBaseURI;
    string private climaxURIPostfix;
    mapping(uint256 => address) public convertedMap;
    mapping(address => uint256[]) private _userConvertedTokens;

    event ConvertSpaceship(address nft, address owner, uint256[] tokenIds);
    event TransferOgSpaceshipClimaxOwner(address newOwner);

    function initialize(
        address initialOwner,
        address _ogSpaceshipDebut,
        address _ogSpaceshipClimax
    ) external initializer {
        __Ownable_init(initialOwner);
        ogSpaceshipDebut = IOgSpaceship(_ogSpaceshipDebut);
        ogSpaceshipClimax = IOgSpaceship(_ogSpaceshipClimax);
    }

    function convertSpaceship(uint256[] memory tokenIds) external {
        require(tokenIds.length > 0, 'INVALID SIZE');
        address owner = msg.sender;
        require(ogSpaceshipDebut.isApprovedForAll(owner, address(this)), 'NEED APPROVAL');

        for(uint256 index = 0; index < tokenIds.length; index++) {
            uint256 tokenId = tokenIds[index];
            require(ogSpaceshipDebut.ownerOf(tokenId) == owner, 'ONLY OWNER CAN CONVERT');
            require(convertedMap[tokenId] == address(0), 'ALREADY LOCKED TOKEN');
            ogSpaceshipDebut.safeTransferFrom(owner, address(this), tokenId);
            convertedMap[tokenId] = owner;
            _userConvertedTokens[owner].push(tokenId);
            ogSpaceshipDebut.burn(tokenId);
            ogSpaceshipClimax.mint(owner, tokenId, _getClimaxTokenUri(tokenId));
        }

        emit ConvertSpaceship(address(ogSpaceshipDebut), owner, tokenIds);
    }

    function checkConverted(uint256[] memory tokenIds) external view returns (bool[] memory) {
        bool[] memory results = new bool[](tokenIds.length);
        for(uint256 index = 0; index < tokenIds.length; index++) {
            results[index] = convertedMap[tokenIds[index]] != address(0);
        }
        return results;
    }

    function getConvertedTokens(address owner) external view returns (uint256[] memory) {
        return _userConvertedTokens[owner];
    }

    function transferOgSpaceshipClimaxOwner(address newOwner) external onlyOwner {
        ogSpaceshipClimax.transferOwnership(newOwner);
        emit TransferOgSpaceshipClimaxOwner(newOwner);
    }

    function onERC721Received(address, address, uint256, bytes memory) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function setClimaxBaseURI(string memory uri) external onlyOwner {
        climaxBaseURI = uri;
    }

    function setClimaxURIPostfix(string memory climaxUriPostfix) external onlyOwner {
        climaxURIPostfix = climaxUriPostfix;
    }

    function _getClimaxTokenUri(uint256 tokenId) internal view returns (string memory) {
        return bytes(climaxBaseURI).length > 0 ? string.concat(climaxBaseURI, tokenId.toString(), climaxURIPostfix) : "";
    }
}
