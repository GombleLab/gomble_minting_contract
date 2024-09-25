pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ISpaceKid.sol";

contract SpaceKidMint is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using ECDSA for bytes32;

    struct StageInfo {
        bool registered;
        uint256 stage;
        uint256 startTime;
        uint256 endTime;
        uint256 maxMint;
    }

    address private signer;
    ISpaceKid public spaceKid;
    mapping(uint256 => bool) private _mintedByOgTokens;
    mapping(address => uint256[]) private _userMintedByOgTokens;
    mapping(uint256 => mapping(address => uint256)) private _whitelist;
    mapping(uint256 => mapping(address => uint256)) private _whitelistMinted;
    mapping(uint256 => StageInfo) private _stageInfos;
    mapping(uint256 => uint256) private _stageMinted;

    error MintFailed(address to, uint256 tokenIndex);

    event MintByOg(address owner, uint256[] ogIds, uint256 count);
    event MintByStage(address owner, uint256 stage, uint256 count);
    event SetStageInfo(uint256 stage, uint256 startTime, uint256 endTime, uint256 maxMint);

    function initialize(
        address initialOwner,
        address _signer,
        ISpaceKid _spaceKid
    ) external initializer {
        __Ownable_init(initialOwner);
        signer = _signer;
        spaceKid = _spaceKid;
    }

    function setStages(
        uint256[] memory stages,
        uint256[] memory startTimes,
        uint256[] memory endTimes,
        uint256[] memory maxMints
    ) external onlyOwner {
        require(stages.length == startTimes.length && stages.length == endTimes.length && stages.length == maxMints.length, "INVALID SIZE");
        for (uint256 index = 0; index < stages.length; index++) {
            _setStage(stages[index], startTimes[index], endTimes[index], maxMints[index]);
        }
    }

    function setStage(uint256 stage, uint256 startTime, uint256 endTime, uint256 maxMint) external onlyOwner {
        _setStage(stage, startTime, endTime, maxMint);
    }

    function updateStageTime(uint256 stage, uint256 startTime, uint256 endTime) external onlyOwner {
        _setStage(stage, startTime, endTime, _stageInfos[stage].maxMint);
    }

    function mintByOg(uint256[] memory ogIds, uint256 count, bytes memory signature) external {
        require(ogIds.length <= count, 'INVALID COUNT');
        address user = msg.sender;
        _verifySignature(signer, user, ogIds, count, signature);

        for (uint256 index = 0; index < ogIds.length; index++) {
            uint256 ogId = ogIds[index];
            require(!_mintedByOgTokens[ogId], 'ALREADY MINTED TOKEN');
            _userMintedByOgTokens[user].push(ogId);
            _mintedByOgTokens[ogId] = true;
        }

        for (uint256 index = 0; index < count; index++) {
            _mint(user);
        }

        emit MintByOg(user, ogIds, count);
    }

    function mintByStage(uint256 stage) external nonReentrant {
        StageInfo memory stageInfo = _stageInfos[stage];
        require(stageInfo.registered, 'INVALID STAGE');
        require(stageInfo.startTime <= block.timestamp, 'NOT STARTED');
        require(stageInfo.endTime > block.timestamp, 'ENDED');

        uint256 remainingMint = stageInfo.maxMint - _stageMinted[stage];
        require(remainingMint > 0, 'MAX MINTED');

        uint256 userWhitelistCount = _whitelist[stage][msg.sender];
        require(userWhitelistCount > 0, 'NOT WHITELISTED');

        uint256 userMintingCount = _whitelistMinted[stage][msg.sender];
        require(userMintingCount < userWhitelistCount, 'USER MINTED ALL');

        uint256 mintCount = userWhitelistCount - userMintingCount;

        if (mintCount > remainingMint) {
            mintCount = remainingMint;
        }

        for (uint256 index = 0; index < mintCount; index++) {
            _mint(msg.sender);
        }

        _whitelistMinted[stage][msg.sender] += mintCount;
        _stageMinted[stage] += mintCount;
        emit MintByStage(msg.sender, stage, mintCount);
    }

    function addWhitelist(uint256 stage, address[] memory users, uint256[] memory counts) external onlyOwner {
        require(users.length == counts.length, 'INVALID SIZE');
        for (uint256 index = 0; index < users.length; index++) {
            _whitelist[stage][users[index]] = counts[index];
        }
    }

    function bulkMint(uint256 stage, address to, uint256 count) external onlyOwner {
        StageInfo memory stageInfo = _stageInfos[stage];
        require(stageInfo.registered, 'INVALID STAGE');
        require(stageInfo.startTime <= block.timestamp, 'NOT STARTED');
        uint256 remainingMint = stageInfo.maxMint - _stageMinted[stage];
        require(remainingMint >= count, 'MAX MINTED');
        for (uint256 index = 0; index < count; index++) {
            _mint(to);
        }
        _stageMinted[stage] += count;
    }

    function checkMintedByOg(uint256 ogId) external view returns (bool) {
        return _mintedByOgTokens[ogId] == true;
    }

    function getWhitelist(uint256 stage, address user) external view returns (uint256) {
        return _whitelist[stage][user];
    }

    function getWhitelistMinted(uint256 stage, address user) external view returns (uint256) {
        return _whitelistMinted[stage][user];
    }

    function getWhitelistByStages(uint256[] memory stages, address user) external view returns (uint256[] memory) {
        uint256[] memory whitelist = new uint256[](stages.length);
        for (uint256 index = 0; index < stages.length; index++) {
            whitelist[index] = _whitelist[stages[index]][user];
        }
        return whitelist;
    }

    function getWhitelistMintedByStages(uint256[] memory stages, address user) external view returns (uint256[] memory) {
        uint256[] memory whitelistMinted = new uint256[](stages.length);
        for (uint256 index = 0; index < stages.length; index++) {
            whitelistMinted[index] = _whitelistMinted[stages[index]][user];
        }
        return whitelistMinted;
    }

    function getStageMinted(uint256 stage) external view returns (uint256) {
        return _stageMinted[stage];
    }

    function getStageInfo(uint256 stage) external view returns (StageInfo memory) {
        return _stageInfos[stage];
    }

    function getStageInfos(uint256[] memory stages) external view returns (StageInfo[] memory) {
        StageInfo[] memory stageInfos = new StageInfo[](stages.length);
        for (uint256 index = 0; index < stages.length; index++) {
            stageInfos[index] = _stageInfos[stages[index]];
        }
        return stageInfos;
    }

    function getMintedByOgTokens(address owner) external view returns (uint256[] memory) {
        return _userMintedByOgTokens[owner];
    }

    function _setStage(uint256 stage, uint256 startTime, uint256 endTime, uint256 maxMint) internal {
        require(startTime < endTime, 'INVALID TIME');
        StageInfo memory _stageInfo = _stageInfos[stage];
        if (_stageInfo.registered) {
            require(_stageInfo.stage == stage, 'INVALID STAGE');
            _stageInfo.startTime = startTime;
            _stageInfo.endTime = endTime;
            _stageInfo.maxMint = maxMint;
        } else {
            _stageInfo.registered = true;
            _stageInfo.stage = stage;
            _stageInfo.startTime = startTime;
            _stageInfo.endTime = endTime;
            _stageInfo.maxMint = maxMint;
        }
        _stageInfos[stage] = _stageInfo;
        emit SetStageInfo(stage, startTime, endTime, maxMint);
    }

    function _mint(address to) internal {
        try spaceKid.mint(to, spaceKid.totalSupply()) {
        } catch {
            revert MintFailed(to, spaceKid.totalSupply());
        }
    }

    function _verifySignature(address owner, address sender, uint256[] memory ogIds, uint256 count, bytes memory signature) internal {
        bytes32 messageHash = keccak256(abi.encode(sender, ogIds, count));
        address _signer = MessageHashUtils.toEthSignedMessageHash(messageHash).recover(signature);
        require(_signer == owner, 'INVALID SIGNATURE');
    }
}
