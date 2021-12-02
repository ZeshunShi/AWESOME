const path = require('path');
const fs = require('fs');
var bodyParser = require('body-parser');
var urlencodedParser = bodyParser.urlencoded({
  extended: true
});
const {
  Gateway,
  Wallets
} = require('fabric-network');
const {
  buildCCPOrg1,
  buildCCPOrg2,
  buildWallet,
  prettyJSONString
} = require('../util/AppUtil.js');

var user = process.argv[3];

async function getGateway(){
  try {
    const ccp = buildCCPOrg1();
    const walletPath = path.join(__dirname, '../wallet/org1');
    const wallet = await buildWallet(Wallets, walletPath);
    const gateway = new Gateway();
    await gateway.connect(ccp, {
      wallet,
      identity: user,
      discovery: {
        enabled: true,
        asLocalhost: true
      }
    });
    return gateway;
  } catch (error) {
    console.error(`Failed to create gateway: ${error}`);
    process.exit(1);
  }
}

async function endAuction(auctionID) {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    var slaID = Math.floor(Math.random() * 1000);
    const result = await contract.submitTransaction('endAuction', auctionID, slaID);
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

async function submitAuction(auction, user) {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    var key = Math.floor(Math.random() * 1000);
    const result = await contract.submitTransaction('submitAuction', key, JSON.stringify(auction), auction.auctionType, auction.auctionDirection);
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

async function queryService(requestID) {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    const result = await contract.evaluateTransaction('queryService', requestID);
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

async function submitBid(bid) {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    const result = await contract.submitTransaction('submitBid', bid.auctionID, bid.owner, bid);
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

async function queryAllServicesAsOwner(providerID) {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    const result = await contract.evaluateTransaction('queryAllServicesAsOwner');
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

async function queryAllSLAs(owner) {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    const result = await contract.evaluateTransaction('queryAllSLAs');
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

module.exports = {
  getMySLAsInfo: async function(app) {
    app.get('/ui_provider/mySLAsInfo:providerID', async function(req, res) {
      result = await queryAllSLAs(req.params.providerID);
      console.log(result);
      res.send(result);
    })
  },
  getMySLAs: async function(app) {
    app.get('/ui_provider/mySLAs', async function(req, res) {
      //let route = `GET /path1/path2/${req.params.providerID}`;
      res.render('ui_provider/mySLAs.ejs');
    })
  },
  postEndAuction: async function(app) {
    app.post('/ui_provider/endAuction', urlencodedParser, async function(req, res) {
      //console.log("here");
      //console.log(req.body);
      console.log(req.body.auctionID);
      result = await endAuction(req.body.auctionID);
      console.log("here");
      console.log(JSON.parse(result));
      //result2 = await queryAllSLAs();
      //console.log("here2");
      //console.log(JSON.stringify(JSON.parse(result2)));
      var redir = {
        redirect: "/ui_provider/postAuctionThankYou"
      };
      return res.json(redir);
    })
  },
  getAuctionCardInfo: async function(app) {
    app.get('/ui_provider/aCard:auctionID', async function(req, res) {
      result = await queryService(req.params.auctionID);
      res.send(result);
    })
  },
  getAuctionCard: async function(app) {
    app.get('/ui_provider/auctionCard?:auctionID', async function(req, res) {
      let route = `GET /path1/path2/${req.params.auctionID}`;
      res.render('ui_provider/auctionCard.ejs');
    })
  },
  getMyAuctionsInfo: async function(app) {
    app.get('/ui_provider/myAuctionsInfo:providerID', async function(req, res) {
      result = await queryAllServicesAsOwner(req.params.providerID);
      console.log(result);
      res.send(result);
    })
  },
  getMyAuctions: async function(app) {
    app.get('/ui_provider/myAuctions', async function(req, res) {
      //let route = `GET /path1/path2/${req.params.providerID}`;
      res.render('ui_provider/myAuctions.ejs');
    })
  },
  postFullAuction: function(app) {
    app.post('/ui_provider/postFullAuction', urlencodedParser, async function(req, res) {
      console.log(req.body);
      result = await submitAuction(req.body, user);
      console.log(result);
      var redir = {
        redirect: "/ui_provider/postAuctionThankYou"
      };
      return res.json(redir);
    })
  },
  getPostAuction: function(app) {
    app.get('/ui_provider/postAuction', urlencodedParser, async function(req, res) {
      res.render('ui_provider/postAuction.ejs');
    })
  },
  getPostBidThankYou: function(app) {
    app.get('/ui_provider/getPostBidThankYou', urlencodedParser, async function(req, res) {
      res.render('ui_provider/getPostBidThankYou.ejs');
    })
  },
  postFullBid: function(app) {
    app.post('/ui_provider/postFullBid', urlencodedParser, async function(req, res) {
      console.log(req.body);
    })
  },
  getProviderCardInfo: async function(app) {
    app.get('/ui_provider/pCard:serviceID', async function(req, res) {
      result = await queryService(req.params.serviceID);
      res.send(result);
    })
  },
  getProviderCard: async function(app) {
    app.get('/ui_provider/providerCard?:serviceID', async function(req, res) {
      let route = `GET /path1/path2/${req.params.serviceID}`;
      res.render('ui_provider/providerCard.ejs');
    })
  },
  getPostAuctionThankYou: function(app) {
    app.get('/ui_provider/postAuctionThankYou', function(req, res) {
      //var passedVariable = req.query.valid;
      //console.log(passedVariable);
      res.render('ui_provider/postAuctionThankYou.ejs');
    })
  },
  getProvider: function(app) {
    app.get('/ui_provider/provider', function(req, res) {
      res.render('ui_provider/provider.ejs');
    })
  }
}
