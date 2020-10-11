from brownie import OVLToken, OVLFPosition, OVLChainlinkFeed, accounts

def main():
    # Deploy OVL ERC20 with minter role given to deployer
    acct = accounts.load('test_1') # TODO: ovl_deployer
    token = OVLToken.deploy("Overlay Test Token", "OVL", {'from': acct})
    token.grantRole(token.MINTER_ROLE(), acct.address)

    print("Does {} have default admin role?".format(acct.address))
    hasDefaultAdmin = token.hasRole(token.DEFAULT_ADMIN_ROLE(), acct.address)
    print(hasDefaultAdmin)

    print("Does {} have minter role?".format(acct.address))
    hasMinter = token.hasRole(token.MINTER_ROLE(), acct.address)
    print(hasMinter)

    # TODO: Deploy OVL faucet contract for alpha trading


    # TODO: Mint 10,000 of total 100,000 OVL to faucet


    # Deploy Chainlink BTCUSD feed && associated FPosition
    feed_btcusd_chainlink = OVLChainlinkFeed.deploy(
        '0x6135b13325bfC4B00278B4abC5e20bbce2D6580e', # Kovan feed; TODO: debug issues with Kovan deploy
        {'from': acct}
    )
    print("Feed data source: {}".format(feed_btcusd_chainlink.dataSource()))

    position_btcusd_chainlink = OVLFPosition.deploy(
        "uri", token.address, feed_btcusd_chainlink.address,
        {'from': acct}
    )
    print("Position governance: {}".format(position_btcusd_chainlink.governance()))
    print("Position feed: {}".format(position_btcusd_chainlink.feed()))
    print("Position treasury: {}".format(position_btcusd_chainlink.treasury()))
