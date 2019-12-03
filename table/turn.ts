import * as R from "ramda";
import * as maps from "../maps";
import endGame from "./endGame";
import { rand } from "../rand";
import logger from "../logger";
import { Table, Land, Player, CommandResult, CommandType } from "../types";
import {
  updateLand,
  groupedPlayerPositions,
  removePlayerCascade,
} from "../helpers";

import {
  ELIMINATION_REASON_OUT,
  ELIMINATION_REASON_SURRENDER,
  OUT_TURN_COUNT_ELIMINATION,
} from "../constants";
import { now } from "../timestamp";

const turn = (
  type: CommandType,
  table: Table,
  sitPlayerOut = false
): CommandResult => {
  const inPlayers = sitPlayerOut
    ? R.adjust(
        player => ({ ...player, out: true }),
        table.turnIndex,
        table.players
      )
    : table.players;

  const currentPlayer = inPlayers[table.turnIndex];
  const [lands, players] = currentPlayer
    ? giveDice(table, table.lands, inPlayers)(currentPlayer) // not just removed
    : [table.lands, table.players];

  const nextIndex =
    table.turnIndex + 1 < players.length ? table.turnIndex + 1 : 0;

  const props = {
    turnIndex: nextIndex,
    turnStart: now(),
    turnActivity: false,
    turnCount: table.turnCount + 1,
    roundCount: nextIndex === 0 ? table.roundCount + 1 : table.roundCount,
  };

  const newPlayer = players[props.turnIndex];

  const positions = groupedPlayerPositions(table);
  const position = positions(newPlayer);
  if (
    newPlayer.flag !== null &&
    newPlayer.flag >= position &&
    position === table.players.length
  ) {
    const elimination = {
      player: newPlayer,
      position: players.length,
      reason: ELIMINATION_REASON_SURRENDER,
      source: {
        flag: newPlayer.flag,
      },
    };
    const [players_, lands_, turnIndex, eliminations] = removePlayerCascade(
      table,
      table.players,
      table.lands,
      newPlayer,
      table.turnIndex,
      elimination
    );

    if (players_.length === players.length) {
      throw new Error(`could not remove player ${newPlayer.id}`);
    }
    props.turnIndex = turnIndex;
    // props.turnIndex =
    // props.turnIndex + 1 < players_.length ? props.turnIndex + 1 : 0;

    const result = {
      type,
      table: props,
      lands: lands_,
      players: players_,
      eliminations,
    };

    if (players_.length === 1) {
      // okthxbye
      return endGame(table, result);
    } else {
      return result;
    }
  }

  if (!newPlayer.out) {
    // normal turn over
    return { type, table: props, lands, players };
  }

  if (newPlayer.outTurns > OUT_TURN_COUNT_ELIMINATION) {
    const elimination = {
      player: newPlayer,
      position: players.length,
      reason: ELIMINATION_REASON_OUT,
      source: {
        turns: newPlayer.outTurns,
      },
    };
    const [players_, lands_, turnIndex, eliminations] = removePlayerCascade(
      table,
      table.players,
      table.lands,
      newPlayer,
      table.turnIndex,
      elimination
    );
    props.turnIndex = turnIndex;

    const result = {
      type,
      table: props,
      lands: lands_,
      players: players_,
      eliminations,
    };

    if (players_.length === 1) {
      // okthxbye
      return endGame(table, result);
    } else {
      return result;
    }
  }

  return {
    type,
    table: props,
    lands: lands,
    players: players.map(player => {
      if (player === newPlayer) {
        return { ...player, outTurns: player.outTurns + 1 };
      }
      return player;
    }),
  };
};

const giveDice = (
  table: Table,
  lands: ReadonlyArray<Land>,
  players: ReadonlyArray<Player>
) => (player: Player): [ReadonlyArray<Land>, ReadonlyArray<Player>] => {
  const connectLandCount = maps.countConnectedLands({
    lands,
    adjacency: table.adjacency,
  })(player.color);
  const newDies = connectLandCount + player.reserveDice;

  let reserveDice = 0;

  let filledLands = lands;
  R.range(0, newDies).forEach(i => {
    const targets = lands.filter(
      land => land.color === player.color && land.points < table.stackSize
    );
    if (targets.length === 0) {
      reserveDice += 1;
    } else {
      let index = rand(0, targets.length - 1);
      const target = targets[index];
      lands = updateLand(lands, target, { points: target.points + 1 });
    }
  });
  return [
    lands,
    players.map(p => (p === player ? { ...player, reserveDice } : p)),
  ];
};

export default turn;
