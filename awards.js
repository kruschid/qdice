require("ts-node").register({
  cache: process.env.NODE_ENV === "production",
});
if (process.env.NODE_ENV === "production") {
  const Sentry = require("@sentry/node");
  Sentry.init({
    dsn: "https://59056e4129274cbf98f70045c017bfe8@sentry.io/1862503",
  });
}
require("./awards.ts").awards();
