const R = require('ramda');
const publish = require('./publish');

module.exports = (user, table, clientId, payload) => {
  publish.chat(table, user ? user.name : null, payload);
};


