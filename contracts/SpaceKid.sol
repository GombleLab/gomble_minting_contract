pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract SpaceKid is ERC721Enumerable, Ownable {
    using Strings for uint256;

    address private minter;
    string private __baseURI;
    string private _uriPostfix;
    bool private _mintable;
    bool private _transferable;

    event ChangeMinter(address oldMinter, address newMinter);
    event FreezeMint();
    event UnfreezeMint();
    event FreezeTransfer();
    event UnfreezeTransfer();
    event SetBaseURI(string baseURI);
    event SetURIPostfix(string uriPostfix);

    modifier onlyMinter() {
        require(minter == msg.sender, 'INVALID MINTER');
        _;
    }

    constructor(
        string memory name,
        string memory symbol,
        address initialOwner
    ) public ERC721(name, symbol) Ownable(initialOwner){
        _mintable = true;
        _transferable = true;
    }

    function getTokensByOwner(address owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(owner);
        uint256[] memory tokenIds = new uint256[](balance);
        for (uint256 index = 0; index < balance; index++) {
            tokenIds[index] = tokenOfOwnerByIndex(owner, index);
        }
        return tokenIds;
    }

    function bulkMint(address[] memory targets, uint256[] memory tokenIds) external onlyMinter {
        require(_mintable, 'MINTING IS FROZEN');
        require(targets.length == tokenIds.length, 'INVALID SIZE');
        for (uint256 index = 0; index < tokenIds.length; index++) {
            require(super._ownerOf(tokenIds[index]) == address(0), 'ALREADY MINTED TOKEN');
            _safeMint(targets[index], tokenIds[index]);
        }
    }

    function mint(address to, uint256 tokenId) external onlyMinter {
        require(_mintable, 'MINTING IS FROZEN');
        require(super._ownerOf(tokenId) == address(0), 'ALREADY MINTED TOKEN');
        _safeMint(to, tokenId);
    }

    function freezeMint() external onlyOwner {
        _mintable = false;
        emit FreezeMint();
    }

    function unfreezeMint() external onlyOwner {
        _mintable = true;
        emit UnfreezeMint();
    }

    function freezeTransfer() external onlyOwner {
        _transferable = false;
        emit FreezeTransfer();
    }

    function unfreezeTransfer() external onlyOwner {
        _transferable = true;
        emit UnfreezeTransfer();
    }

    function setBaseURI(string memory baseURI) external onlyOwner {
        __baseURI = baseURI;
        emit SetBaseURI(baseURI);
    }

    function setURIPostfix(string memory uriPostfix) external onlyOwner {
        _uriPostfix = uriPostfix;
        emit SetURIPostfix(uriPostfix);
    }

    function changeMinter(address newMinter) external onlyOwner {
        address oldBurner = minter;
        minter = newMinter;
        emit ChangeMinter(oldBurner, newMinter);
    }

    function isMintable() external view returns (bool) {
        return _mintable;
    }

    function isTransferable() external view returns (bool) {
        return _transferable;
    }

    function transferFrom(address from, address to, uint256 tokenId) public virtual override (ERC721, IERC721) {
        require(_transferable, 'TRANSFER IS FROZEN');
        super.transferFrom(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data) public virtual override (ERC721, IERC721) {
        require(_transferable, 'TRANSFER IS FROZEN');
        super.safeTransferFrom(from, to, tokenId, data);
    }

    /**
    * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId)
    public
    view
    override
    returns (string memory) {
        _requireOwned(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string.concat(baseURI, tokenId.toString(), _uriPostfix) : "";
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overridden in child contracts.
     */
    function _baseURI() internal override(ERC721) view returns (string memory) {
        return __baseURI;
    }
}
