# @version 0.2.11
"""
@title Mock ERC721
@dev Provides a utility `_mint_for_testing` function which allows any caller to mint
    a new token
"""


TOKEN_RECEIVED: constant(Bytes[4]) = 0x150b7a02


interface ERC721TokenReceiver:
    def onERC721Received(
        _operator: address, _from: address, _tokenId: uint256, _data: Bytes[1024]
    ) -> Bytes[4]: nonpayable


event Approval:
    _owner: indexed(address)
    _approved: indexed(address)
    _tokenId: indexed(uint256)

event ApprovalForAll:
    _owner: indexed(address)
    _operator: indexed(address)
    _approved: bool

event Transfer:
    _from: indexed(address)
    _to: indexed(address)
    _tokenId: indexed(uint256)


totalSupply: public(uint256)

balanceOf: public(HashMap[address, uint256])
ownerOf: public(HashMap[uint256, address])
isApprovedForAll: public(HashMap[address, HashMap[address, bool]])
getApproved: public(HashMap[uint256, address])


@internal
def _mint(_to: address):
    assert _to != ZERO_ADDRESS  # dev: Minting to zero address disallowed

    token_id: uint256 = self.totalSupply
    self.balanceOf[_to] += 1
    self.ownerOf[token_id] = _to
    self.totalSupply += 1

    log Transfer(ZERO_ADDRESS, _to, token_id)


@internal
def _transferFrom(_from: address, _to: address, _tokenId: uint256):
    assert _to != ZERO_ADDRESS  # dev: Transfers to ZERO_ADDRESS not permitted

    self.getApproved[_tokenId] = ZERO_ADDRESS
    self.balanceOf[_from] -= 1
    self.balanceOf[_to] += 1
    self.ownerOf[_tokenId] = _to

    log Transfer(_from, _to, _tokenId)


@external
def _mint_for_testing(_to: address):
    self._mint(_to)


@external
def setApprovalForAll(_operator: address, _approved: bool):
    self.isApprovedForAll[msg.sender][_operator] = _approved

    log ApprovalForAll(msg.sender, _operator, _approved)


@payable
@external
def approve(_approved: address, _tokenId: uint256):
    token_owner: address = self.ownerOf[_tokenId]
    assert (
        msg.sender == token_owner or self.isApprovedForAll[token_owner][msg.sender]
    )  # dev: Caller is neither owner nor operator

    self.getApproved[_tokenId] = _approved

    log Approval(token_owner, _approved, _tokenId)


@payable
@external
def transferFrom(_from: address, _to: address, _tokenId: uint256):
    token_owner: address = self.ownerOf[_tokenId]
    assert (
        msg.sender == token_owner
        or self.isApprovedForAll[token_owner][msg.sender]
        or self.getApproved[_tokenId] == msg.sender
    )  # dev: Caller is neither owner nor operator nor approved

    self._transferFrom(_from, _to, _tokenId)


@payable
@external
def safeTransferFrom(
    _from: address, _to: address, _tokenId: uint256, _data: Bytes[1024] = b""
):
    token_owner: address = self.ownerOf[_tokenId]
    assert (
        msg.sender == token_owner
        or self.isApprovedForAll[token_owner][msg.sender]
        or self.getApproved[_tokenId] == msg.sender
    )  # dev: Caller is neither owner nor operator nor approved

    self._transferFrom(_from, _to, _tokenId)

    if _to.is_contract:
        return_value: Bytes[8] = ERC721TokenReceiver(_to).onERC721Received(
            msg.sender, _from, _tokenId, _data
        )  # dev: bad response
        assert (
            return_value == TOKEN_RECEIVED
        )  # dev: Invalid ERC721TokenReceiver response
