import * as R from "ramda";
import { BotStrategy, BotPlayer, Table, Land, Color, Player } from "../types";
import logger from "../logger";
import { landMasses } from "../maps";

export type Source = { source: Land; targets: Land[] };
export type Attack = { from: Land; to: Land; wheight: number };

type Tactic = (
  bestChance: number,
  source: Land,
  target: Land,
  player?: BotPlayer,
  table?: Table
) => Attack | undefined;

export const move = (strategy: BotStrategy) => {
  return (
    sources: Source[],
    player: BotPlayer,
    table: Table
  ): Attack | null => {
    const apply = applyTactic(sources, player, table);

    let attack: Attack | null = null;
    if (hasDisconnectedLands(player, table)) {
      attack = apply(tactics.reconnect);
      if (attack) {
        return attack;
      }
    }

    const tactic: Tactic = pickTactic(strategy, player, table);
    return apply(tactic);
  };
};

const applyTactic = (sources: Source[], player: BotPlayer, table: Table) => (
  tactic: Tactic
): Attack | null =>
  sources.reduce<Attack | null>(
    (attack, { source, targets }) =>
      targets.reduce((attack: Attack, target: Land): Attack => {
        const bestChance = attack ? attack.wheight : -Infinity;

        const result = tactic(bestChance, source, target, player, table);
        return result ?? attack;
      }, attack),
    null
  );

export const pickTactic = (
  strategy: BotStrategy,
  player: BotPlayer,
  table: Table
): Tactic => {
  switch (strategy) {
    case "RandomCareless":
      return tactics.careless;
    case "Revengeful":
      const lastAgressorColor =
        table.players.find(p => p.id === player.bot.state.lastAgressor)
          ?.color ?? null;

      if (
        table.lands
          .filter(l => l.color === player.color)
          .every(l => l.points === table.stackSize)
      ) {
        return tactics.careless;
      }
      if (table.players.length > 2) {
        return tactics.focusColor(lastAgressorColor ?? Color.Neutral);
      }
    case "RandomCareful":
    default:
      return tactics.careful;
  }
};

export const tactics = {
  careful: (bestChance: number, source: Land, target: Land) => {
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      if (
        thisChance > 0 ||
        (target.color === Color.Neutral && thisChance == 0)
      ) {
        return { from: source, to: target, wheight: thisChance };
      }
    }
  },

  careless: (bestChance: number, source: Land, target: Land) => {
    const thisChance = source.points - target.points;
    if (thisChance > bestChance) {
      return { from: source, to: target, wheight: thisChance };
    }
  },

  focusColor: (color: Color) =>
    function focusColor(bestChance: number, source: Land, target: Land) {
      if (target.color === color) {
        if (color === Color.Neutral) {
          return tactics.careful(bestChance, source, target);
        }
        return tactics.careless(bestChance, source, target);
      }
    },

  reconnect: (
    bestChance: number,
    source: Land,
    target: Land,
    player: BotPlayer,
    table: Table
  ) => {
    const currentCount = landMasses(table)(player.color).length;

    const newTable = {
      ...table,
      lands: table.lands.map(l =>
        l.emoji === target.emoji ? { ...l, color: source.color } : l
      ),
    };

    if (landMasses(newTable)(player.color).length < currentCount) {
      const thisChance = source.points - target.points;
      if (thisChance > bestChance) {
        return { from: source, to: target, wheight: thisChance };
      }
    }
  },
};

export const hasDisconnectedLands = (player: Player, table: Table): boolean => {
  return landMasses(table)(player.color).length > 1;
};