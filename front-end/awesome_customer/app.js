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

//uiCustomer routes
var cust = require('./routes/uiCustomerRoutes.js');
cust.getCustomer(app); //yes
cust.getPostAuctionThankYou(app); //yes
cust.postFullAuction(app); //yes
cust.getBrowseAuctions(app); //yes
cust.getBrowseAuctionsQuery(app); //yes
cust.getCustomerCard(app); //yes
cust.getCustomerCardInfo(app); // yes
cust.postFullBid(app); //yes
cust.getMySLAs(app);
cust.getMySLAsInfo(app);
//end UI Customer
//console.log(process.argv[2]);

app.listen(process.argv[2]);
console.log(`Server is listening on port ${process.argv[2]}`);
