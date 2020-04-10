import logger from "./logger";
logger.info("Qdice server starting");

import * as fs from "fs";
import * as db from "./db";
import * as table from "./table";

import * as R from "ramda";

import * as restify from "restify";
import * as corsMiddleware from "restify-cors-middleware";
import * as jwt from "restify-jwt-community";
import * as mqtt from "mqtt";
import * as AsyncLock from "async-lock";

import * as globalServer from "./global";
import { leaderboard } from "./leaderboard";
import { screenshot } from "./screenshot";
import * as publish from "./table/publish";
import * as user from "./user";
import { profile } from "./profile";
import * as games from "./games";
import { resetGenerator } from "./rand";
import { clearMemoryTables } from "./table/get";

process.on("unhandledRejection", (reason, p) => {
  logger.error("Unhandled Rejection at: Promise", p, "reason:", reason);
  // application specific logging, throwing an error, or other logic here
  throw reason;
});

export const server = async () => {
  const server = restify.createServer();
  server.on("InternalServer", function(req, res, err, cb) {
    // by default, restify will usually render the Error object as plaintext or
    // JSON depending on content negotiation. the default text formatter and JSON
    // formatter are pretty simple, they just call toString() and toJSON() on the
    // object being passed to res.send, which in this case, is the error object.
    // so to customize what it sent back to the client when this error occurs,
    // you would implement as follows:

    // for any response that is text/plain
    err.toString = function toString() {
      return "an internal server error occurred!";
    };
    // for any response that is application/json
    err.toJSON = function toJSON() {
      return {
        message: "an internal server error occurred!",
        code: "boom!",
      };
    };

    return cb();
  });

  server.on("restifyError", function(req, res, err, cb) {
    // this listener will fire after both events above!
    // `err` here is the same as the error that was passed to the above
    // error handlers.
    logger.error(err);
    return cb();
  });

  server.pre(restify.pre.userAgentConnection());
  server.use(restify.plugins.acceptParser(server.acceptable));
  server.use(restify.plugins.authorizationParser());
  server.use(restify.plugins.dateParser());
  server.use(restify.plugins.queryParser());
  server.use(restify.plugins.jsonp());
  server.use(restify.plugins.gzipResponse());
  server.use(restify.plugins.bodyParser());
  server.use(
    restify.plugins.throttle({
      burst: 100,
      rate: 50,
      ip: true,
      overrides: {
        "192.168.1.1": {
          rate: 0, // unlimited
          burst: 0,
        },
      },
    })
  );
  server.use(restify.plugins.conditionalRequest());
  const cors = corsMiddleware({
    preflightMaxAge: 5, //Optional
    origins: [
      "http://localhost:5000",
      "http://lvh.me:5000",
      "https://quedice.host",
      "https://quevic.io",
      "https://qdice.wtf",
      "https://www.qdice.wtf",
      "https://elm-dice.herokuapp.com",
      "https://*.hwcdn.net",
      "http://electron",
      "https://*.ungrounded.net",
      "https://*.konggames.com",
    ],
    allowHeaders: ["authorization"],
    exposeHeaders: ["authorization"],
  });
  server.pre(cors.preflight);
  server.use(cors.actual);
  server.use(
    jwt({
      secret:
        process.argv.slice().pop() === "--quit"
          ? "temp"
          : process.env.JWT_SECRET,
      credentialsRequired: true,
      getToken: function fromHeaderOrQuerystring(req: any) {
        if (
          req.headers.authorization &&
          req.headers.authorization.split(" ")[0] === "Bearer"
        ) {
          const token = req.headers.authorization.split(" ")[1];
          if (token && token.indexOf('"') === 1) {
            logger.error("Some user got a wrapped token!");
            return token.split('"')[1] ?? null;
          }
          return token ?? null;
        }
        return null;
      },
    }).unless({
      custom: (req: any) => {
        const ok = R.anyPass([
          (req: any) => req.path().indexOf(`${root}/login`) === 0,
          (req: any) => req.path() === `${root}/register`,
          (req: any) => req.path() === `${root}/global`,
          (req: any) => req.path() === `${root}/findtable`,
          (req: any) => req.path() === `${root}/leaderboard`,
          (req: any) => req.path() === `${root}/e2e`,
          (req: any) => req.path() === `${root}/push/key`,
          (req: any) => req.path().indexOf(`${root}/screenshot`) === 0,
          (req: any) => req.path().indexOf(`${root}/profile`) === 0,
          (req: any) => req.path() === `${root}/topwebgames`,
          (req: any) => req.path().indexOf(`${root}/games`) === 0,
          (req: any) => req.path() === `${root}/changelog`,
        ])(req);
        return ok;
      },
    })
  );

  if (process.argv.slice().pop() !== "--quit" && !process.env.API_ROOT) {
    throw new Error("API_ROOT_is not set");
  }
  const root = process.env.API_ROOT;

  const lock = new AsyncLock();

  server.post(`${root}/login/:network`, user.login);
  server.post(`${root}/add-login/:network`, user.addLogin);
  server.get(`${root}/me`, user.me);
  server.del(`${root}/me`, user.del);
  server.put(`${root}/me`, user.profile);
  server.put(`${root}/me/password`, user.password);
  server.post(`${root}/register`, user.register);

  server.get(`${root}/global`, globalServer.global);
  server.get(`${root}/findtable`, globalServer.findtable);
  server.get(`${root}/leaderboard`, leaderboard);
  server.get(`${root}/profile/:id`, profile);
  server.get(
    `${root}/screenshot/:table`,
    restify.plugins.throttle({
      burst: 1,
      rate: 0.2,
      ip: true,
      overrides: {
        localhost: {
          burst: 0,
          rate: 0, // unlimited
        },
      },
    }),
    screenshot
  );

  server.listen(process.env.PORT || 5001, function() {
    logger.info("%s listening at %s port %s", server.name, server.url);
  });

  logger.info("connecting to mqtt: " + process.env.MQTT_URL);
  var client = mqtt.connect(process.env.MQTT_URL, {
    clientId: "nodice",
    username: process.env.MQTT_USERNAME,
    password: process.env.MQTT_PASSWORD,
  });
  publish.setMqtt(client);

  client.subscribe("events");
  client.subscribe("death");
  client.on("error", (err: Error) => logger.error(err));
  client.on("close", () => logger.error("mqqt close"));
  client.on("disconnect", () => logger.error("mqqt disconnect"));
  client.on("offline", () => logger.error("mqqt offline"));
  client.on("end", () => logger.error("mqqt end"));

  client.on("connect", () => {
    logger.info("connected to mqtt.");
    if (process.send) {
      process.send("ready");
    }
    publish.setMqtt(client);

    if (process.env.E2E) {
      server.get(`${root}/e2e`, async (req, res) => {
        const ref = resetGenerator();
        logger.debug(`E2E first random value: ${ref()}`);
        await db.clearGames(lock);
        clearMemoryTables();
        res.send(200, "ok.");
      });
    }
  });

  table.startTables(lock, client);

  client.on("message", globalServer.onMessage(lock));

  server.get(`${root}/push/key`, (_, res) => {
    res.sendRaw(200, process.env.VAPID_PUBLIC_KEY);
  });

  server.post(`${root}/push/register`, user.addPushSubscription(true));
  server.del(`${root}/push/register`, user.addPushSubscription(false));
  server.post(`${root}/push/register/events`, user.addPushEvent(true));
  server.del(`${root}/push/register/events`, user.addPushEvent(false));

  server.get(`${root}/topwebgames`, user.registerVote("topwebgames"));
  server.get(`${root}/games`, games.games);
  server.get(`${root}/games/:table`, games.games);
  server.get(`${root}/games/:table/:id`, games.game);

  let changelog = "not loaded";
  fs.readFile("./changelog.md", undefined, (err, file) => {
    if (err) {
      logger.error(err);
    }
    changelog = file.toString();
    logger.debug(`Loaded changelog md (${changelog.split("\n").length} lines)`);
  });
  server.get(`${root}/changelog`, (_, res, next) => {
    res.sendRaw(200, changelog);
    next();
  });

  process.on("SIGINT", async function() {
    logger.info("SIGINT");
    await new Promise(async resolve => {
      const t = setTimeout(resolve, 1000);
      await publish.sigint();
      clearTimeout(t);
      resolve();
    });
    process.exit();
  });

  if (process.argv.slice().pop() === "--quit") {
    logger.info("Will quit in one second");
    process.exit(0);
  } else {
    logger.info("connecting to postgres...");
    await db.retry();
    logger.info("connected to postgres.");
  }
};
