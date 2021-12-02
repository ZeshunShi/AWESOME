//dependencies
var bodyParser = require('body-parser');
var urlencodedParser = bodyParser.urlencoded({
  extended: true
});
const {
  Gateway,
  Wallets
} = require('fabric-network');
//var adm = require('../routes/uiAdminRoutes.js');

module.exports = {
  getIndex: function(app) {
    app.get('/', function(req, res) {
      res.render('index');
    })
  },
  postRegistration: function(app) {
    app.post('/registerUser', urlencodedParser, async function(req, res) {
      //console.log("registered");
      var userInfo = [req.body.role, req.body.email, req.body.username, req.body.password];
      res.render('registerThankYou.ejs', {
        userInfo: userInfo
      });
    })
  },
  postLogin: function(app) {
    app.post('/loginUser', urlencodedParser, async function(req, res) {
      //console.log("registered");
      var userInfo = [req.body.role, req.body.username, req.body.password];
      var encoded = encodeURIComponent(userInfo);
      console.log(encoded);
      //var encodedUserInfo = encodeUIComponent(userInfo);
      if (userInfo[0] == "Admin") {
        //req.session.valid = true;
        //adm.getAdmin(app, encoded);
        req.session.message = encoded;
        res.redirect('ui_admin/admin');
      } else if (userInfo[0] == "Customer") {
        //app.get('/customer', function(req, res));
        res.redirect('ui_customer/customer');
        //res.redirect('/ui_customer/customer');
      } else if (userInfo[0] == "Provider") {
        res.redirect('/ui_provider/provider');
      } else if (userInfo[0] == "Witness") {
        res.render('ui_witness/witness.ejs', {
          userInfo: userInfo
        });
      }
    })
  },
  getLogin: function(app) {
    app.get('/login', function(req, res) {
      res.render('login.ejs');
    })
  },
  getRegistration: function(app) {
    app.get('/register', function(req, res) {
      res.render('register.ejs');
    })
  }
}
