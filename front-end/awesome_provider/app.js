var express = require('express')
var app = express();
var bodyParser = require('body-parser');
app.use(bodyParser.json());
var net = require('net');
// set the view engine to ejs
app.set('view engine', 'ejs');

//homepage routes
var reg = require('./routes/homepageRoutes.js');
reg.getIndex(app);
reg.postRegistration(app);
reg.postLogin(app);
reg.getLogin(app);
reg.getRegistration(app);
//end homepage

//UI Provider
var prov = require('./routes/uiProviderRoutes.js');
prov.getProvider(app); //we need this
prov.getPostAuctionThankYou(app); //yes
prov.getProviderCard(app); //might need later
prov.getProviderCardInfo(app); // might need later
prov.getPostBidThankYou(app); //will need it later, rn very agnostic
prov.postFullBid(app); //-will need it later, might as well keep it
prov.getPostAuction(app); //yes
prov.postFullAuction(app); //yes
prov.getMyAuctions(app); //yes
prov.getMyAuctionsInfo(app);//yes
prov.getAuctionCard(app);//yes
prov.getAuctionCardInfo(app);//yes
prov.postEndAuction(app);
prov.getMySLAs(app);
prov.getMySLAsInfo(app);
//end UI Provider
app.listen(process.argv[2]);
console.log(`Server is listening on port ${process.argv[2]}`);
