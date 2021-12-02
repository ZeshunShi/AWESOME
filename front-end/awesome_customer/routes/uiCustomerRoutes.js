const {
  Gateway,
  Wallets
} = require('fabric-network');
const path = require('path');
const fs = require('fs');
var bodyParser = require('body-parser');
//app.use(bodyParser.json());
var urlencodedParser = bodyParser.urlencoded({
  extended: true
});
const {
  buildCCPOrg1,
  buildCCPOrg2,
  buildWallet,
  prettyJSONString
} = require('../util/AppUtil.js');

var user = process.argv[3];
/*
we want the customer UI to include the following functionalities:
1. customers can view available services posted on the platform
2. custoemrs can select a service and view it more closely
3. customers can add a service to their "myServices" page
4. customers can view and edit their profiles?
5. customers can bid on a selected service and view that bid!
6. customers can edit and resend the service?
*/

async function getGateway() {
  try {
    const ccp = buildCCPOrg2();
    const walletPath = path.join(__dirname, '../wallet/org2');
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

async function queryAllServices() {
  result = '';
  try {
    gateway = await getGateway();
    const network = await gateway.getNetwork('mychannel');
    const contract = network.getContract('awesome');
    const result = await contract.evaluateTransaction('queryAllServicesAsCustomer');
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
    const result = await contract.evaluateTransaction('queryServiceAsCustomer', requestID);
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
    const result = await contract.submitTransaction('submitBid', bid.auctionID, JSON.stringify(bid));
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
    const result = await contract.evaluateTransaction('queryAllSLAs', owner);
    return result;
  } catch (error) {
    console.error(`Failed to evaluate transaction: ${error}`);
    process.exit(1);
  }
}

module.exports = {
  getMySLAsInfo: async function(app) {
    app.get('/ui_customer/mySLAsInfo:customerID', async function(req, res) {
      result = await queryAllSLAs(req.params.customerID);
      console.log(result);
      res.send(result);
    })
  },
  getMySLAs: async function(app) {
    app.get('/ui_customer/mySLAs', async function(req, res) {
      //let route = `GET /path1/path2/${req.params.providerID}`;
      res.render('ui_customer/mySLAs.ejs');
    })
  },
  postFullBid: function(app) {
    app.post('/ui_customer/postFullBid', urlencodedParser, async function(req, res) {
      console.log(req.body);
      result = await submitBid(req.body);
      console.log(result);
      var redir = {
        redirect: "/ui_customer/postAuctionThankYou"
      };
      return res.json(redir);
    })
  },
  getCustomerCardInfo: async function(app) {
    app.get('/ui_customer/cCard:serviceID', async function(req, res) {
      result = await queryService(req.params.serviceID);
      res.send(result);
    })
  },
  getCustomerCard: async function(app) {
    app.get('/ui_customer/customerCard?:serviceID', async function(req, res) {
      let route = `GET /path1/path2/${req.params.serviceID}`;
      res.render('ui_customer/customerCard.ejs');
    })
  },
  getBrowseAuctionsQuery: async function(app) {
    app.get('/ui_customer/browseAuctionsQuery', async function(req, res) {
      auctions = await queryAllServices();
      //console.log(JSON.parse(auctions));
      res.send(auctions);
    })
  },
  getBrowseAuctions: async function(app) {
    app.get('/ui_customer/browseAuctions', async function(req, res) {
      //auctions = await queryAllServices();
      res.render('ui_customer/browseAuctions.ejs');
    })
  },
  postFullAuction: function(app) {
    app.post('/ui_customer/postFullAuction', urlencodedParser, async function(req, res) {
      console.log(req.body);
      try {
        const ccpPath = path.resolve(__dirname, '..', '..', '..', 'test-network', 'organizations', 'peerOrganizations', 'org1.example.com', 'connection-org1.json');
        if (fs.existsSync(ccpPath)) {
          console.log(ccpPath);
          const ccp = JSON.parse(fs.readFileSync(ccpPath, 'utf8'));
          const walletPath = path.join(process.cwd(), 'wallet');
          const wallet = await Wallets.newFileSystemWallet(walletPath);
          console.log(`Wallet path: ${walletPath}`);
          const gateway = new Gateway();
          await gateway.connect(ccp, {
            wallet,
            identity: 'appUser1',
            discovery: {
              enabled: true,
              asLocalhost: true
            }
          });
          const network = await gateway.getNetwork('mychannel');
          const contract = network.getContract('awesome');

          var key = Math.floor(Math.random() * 1000);
          var owner = req.body.owner; //this is ok

          await contract.submitTransaction('submitAuction', key, owner, JSON.stringify(req.body));

          console.log('Transaction has been submitted');
          //console.log("here");
          //res.redirect('/ui_customer/postAuctionThankYou');
          var redir = {
            redirect: "/ui_customer/postAuctionThankYou"
          };
          return res.json(redir);
          await gateway.disconnect();

        } else {
          console.log(`Directory not found: ${ccpPath}`);
          //res.redirect('/ui_customer/postAuctionThankYou');
          var redir = {
            redirect: "/ui_customer/postAuctionThankYou"
          };
          return res.json(redir);
        }
      } catch (error) {
        console.error(`Failed to evaluate transaction: ${error}`);
        res.status(500).json({
          error: error
        });
        process.exit(1);
      }
    })
  },
  getPostAuctionThankYou: function(app) { //keep
    app.get('/ui_customer/postAuctionThankYou', function(req, res) {
      res.render('ui_customer/postAuctionThankYou.ejs');
    })
  },
  getCustomer: function(app) { //keep
    app.get('/ui_customer/customer', function(req, res) {
      var passedVariable = req.query.valid;
      //console.log(passedVariable);
      res.render('ui_customer/customer.ejs');
    })
  }
}
