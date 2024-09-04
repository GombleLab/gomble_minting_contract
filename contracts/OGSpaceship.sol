pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract OGSpaceship is ERC721URIStorage, OwnableUpgradeable {

    address public burner;
    address public claimer;
    mapping(uint256 => bool) claimMap; // token id => bool
    mapping(uint256 => address) claimUserMap; // token id => claimed user address

    constructor(
        string memory name,
        string memory symbol
    ) public ERC721(name, symbol){}

    event Claim(address owner, uint256 tokenId);
    event ChangeBurner(address oldBurner, address newBurner);
    event ChangeClaimer(address oldClaimer, address newClaimer);

    modifier onlyBurner() {
        require(burner == msg.sender, 'INVALID BURNER');
        _;
    }

    modifier onlyClaimer() {
        require(claimer == msg.sender, 'INVALID CLAIMER');
        _;
    }

    function initialize(
        address initialOwner,
        address _burner,
        address _claimer
    ) external initializer {
        __Ownable_init(initialOwner);
        burner = _burner;
        claimer = _claimer;
    }

    function mint(address to, uint256 tokenId, string memory uri) external onlyOwner {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
    }

    function bulkMint(address to, uint256[] memory tokenIds, string[] memory uris) external onlyOwner {
        require(tokenIds.length == uris.length, 'Invalid Size');

        for(uint256 i = 0; i < tokenIds.length; i++) {
            _safeMint(to, tokenIds[i]);
            _setTokenURI(tokenIds[i], uris[i]);
        }
    }

    function bulkSetTokenURI(uint256[] memory tokenIds, string[] memory uris) external onlyOwner {
        require(tokenIds.length == uris.length, 'Invalid Size');

        for(uint256 i = 0; i < tokenIds.length; i++) {
            _setTokenURI(tokenIds[i], uris[i]);
        }
    }

    function claim(address owner, uint256 tokenId) external onlyClaimer {
        claimMap[tokenId] = true;
        claimUserMap[tokenId] = owner;
        emit Claim(owner, tokenId);
    }

    function changeBurner(address newBurner) external onlyOwner {
        address oldBurner = burner;
        burner = newBurner;
        emit ChangeBurner(oldBurner, newBurner);
    }

    function changeClaimer(address newClaimer) external onlyOwner {
        address oldClaimer = claimer;
        claimer = newClaimer;
        emit ChangeClaimer(oldClaimer, newClaimer);
    }

    function burn(uint256 tokenId) external onlyBurner {
        _burn(tokenId);
    }

    function bulkBurn(uint256[] memory tokenIds) external onlyBurner {
        for(uint256 index = 0; index < tokenIds.length; index ++) {
            _burn(tokenIds[index]);
        }
    }

    function _msgSender() internal view override(Context, ContextUpgradeable) returns (address) {
        return super._msgSender();
    }

    function _msgData() internal view override(Context, ContextUpgradeable) returns (bytes calldata) {
        return super._msgData();
    }

    function _contextSuffixLength() internal view override(Context, ContextUpgradeable) returns (uint256) {
        return super._contextSuffixLength();
    }
}
