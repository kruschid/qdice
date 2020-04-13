export type UserId = string;
export type Network = "google" | "password" | "telegram" | "reddit";
export type Emoji = string;
export type Timestamp = number;

export enum Color {
  Neutral = -1,
  Red = 1,
  Blue = 2,
  Green = 3,
  Yellow = 4,
  Magenta = 5,
  Cyan = 6,
  Orange = 7,
  Black = 8,
  Beige = 9,
}

export type TableProps = {
  readonly playerStartCount: number;
  readonly status: TableStatus;
  readonly gameStart: Timestamp;
  readonly turnIndex: number;
  readonly turnStart: Timestamp;
  readonly turnActivity: boolean;
  readonly turnCount: number;
  readonly roundCount: number;
  readonly attack: Attack | null;
  readonly currentGame: number | null;
};

export type Table = TableProps & {
  readonly name: string;
  readonly tag: string;
  readonly mapName: string;
  readonly adjacency: Adjacency;
  readonly stackSize: number;
  readonly playerSlots: number;
  readonly startSlots: number;
  readonly points: number;

  readonly params: TableParams;

  readonly players: readonly Player[];
  readonly lands: readonly Land[];
  readonly watching: readonly Watcher[];
  readonly retired: readonly Player[];
};

export type TableParams = {
  noFlagRounds: number;
  botLess: boolean;
};

export type Land = {
  readonly emoji: Emoji;
  readonly color: Color;
  readonly points: number;
};

export type Attack = {
  start: Timestamp;
  from: Emoji;
  to: Emoji;
};

export type TableStatus = "PAUSED" | "PLAYING" | "FINISHED";

export type Adjacency = {
  readonly matrix: ReadonlyArray<ReadonlyArray<boolean>>;
  indexes: Readonly<{ [index: string]: number }>;
};

export type UserLike = {
  readonly id: UserId;
  readonly name: string;
  readonly picture: string;
  readonly level: number;
  readonly points: number;
  readonly rank: number;
};

export type User = UserLike & {
  readonly email: string;
  readonly networks: readonly string[];
  readonly claimed: boolean;
  readonly levelPoints: number;
  readonly voted: string[];
  readonly awards: readonly Award[];
};

export type Player = UserLike & {
  readonly clientId: any;
  readonly color: Color;
  readonly reserveDice: number;
  readonly out: boolean;
  readonly outTurns: number;
  readonly points: number;
  readonly awards: readonly Award[];
  readonly position: number;
  readonly score: number;
  readonly flag: number | null;
  readonly lastBeat: Timestamp;
  readonly joined: Timestamp;
  readonly ready: boolean;
  readonly bot: Persona | null;
};

export type Preferences = {};

export type PushNotificationEvents = "game-start";

export type Award = {
  type: "monthly_rank" | "early_adopter";
  position: number;
  timestamp: Date;
};

export type Watcher = {
  clientId: any;
  id: UserId | null;
  name: string | null;
  lastBeat: number;
  death: number;
};

export type Elimination = {
  player: Player;
  position: number;
  reason: EliminationReason;
  source: EliminationSource;
};
export type EliminationSource =
  | { turns: number }
  | { player: Player; points: number }
  | { flag: number; under: null | { player: Player; points: number } };

export type EliminationReason = "☠" | "💤" | "🏆" | "🏳";

export class IllegalMoveError extends Error {
  bot: boolean;

  constructor(message: string, player?: Player | boolean) {
    super(message);
    Object.setPrototypeOf(this, IllegalMoveError.prototype);
    this.bot =
      player === undefined
        ? false
        : typeof player === "boolean"
        ? player
        : !!player.bot;
  }
}

export type CommandType =
  | "Enter"
  | "Exit"
  | "Join"
  | "Takeover"
  | "Leave"
  | "Attack"
  | "EndTurn"
  | "SitOut"
  | "SitIn"
  | "Chat"
  | "ToggleReady"
  | "Flag"
  | "Heartbeat"
  | "Roll"
  | "TickTurnOver"
  | "TickTurnOut"
  | "TickTurnAllOut"
  | "TickStart"
  | "CleanWatchers"
  | "CleanPlayers"
  | "BotState"
  | "EndGame";

type CommandSkeleton<T, P = {}> = {
  readonly type: T;
} & P;
export type Command =
  | CommandSkeleton<"Start">
  | CommandSkeleton<"Enter", { user: User | null; clientId: string }>
  | CommandSkeleton<"Exit", { user: User | null; clientId: string }>
  | CommandSkeleton<"Chat", { user: { name: string } | null; message: string }>
  | CommandSkeleton<
      "Join",
      { user: User; clientId: string | null; bot: Persona | null }
    >
  | CommandSkeleton<"Leave", { player: Player }>
  | CommandSkeleton<"Attack", { player: Player; from: string; to: string }>
  | CommandSkeleton<
      "Roll",
      {
        attacker: Player;
        defender: Player | null;
        from: string;
        to: string;
        fromRoll: number[];
        toRoll: number[];
      }
    >
  | CommandSkeleton<"EndTurn", { player: Player }>
  | CommandSkeleton<"SitOut", { player: Player }>
  | CommandSkeleton<"SitIn", { player: Player }>
  | CommandSkeleton<"ToggleReady", { player: Player; ready: boolean }>
  | CommandSkeleton<"Flag", { player: Player }>
  | CommandSkeleton<"TickTurnOver", { sitPlayerOut: boolean }>
  | CommandSkeleton<"TickTurnOut">
  | CommandSkeleton<"TickTurnAllOut">
  | CommandSkeleton<"EndGame", { winner: Player | null; turnCount: number }>
  | CommandSkeleton<"Clear">
  | CommandSkeleton<"Heartbeat", { user: User | null; clientId: string }>
  | CommandSkeleton<"BotState", { player: Player; botCommand: BotCommand }>;

export type CommandResult = {
  readonly table?: Partial<TableProps>;
  readonly lands?: ReadonlyArray<Land>;
  readonly players?: ReadonlyArray<Player>;
  readonly watchers?: ReadonlyArray<Watcher>;
  readonly eliminations?: ReadonlyArray<Elimination>;
  readonly retired?: ReadonlyArray<Player>;
};

export type BotPlayer = Player & {
  bot: Persona;
};

export type Persona = {
  name: string;
  picture: string;
  strategy: BotStrategy;
  state: BotState;
};

export type BotState = {
  deadlockCount: number;
  lastAgressor: UserId | null;
  surrender: boolean;
};

export type BotStrategy =
  | "RandomCareful"
  | "RandomCareless"
  | "Revengeful"
  | "ExtraCareful"
  | "TargetCareful";

export type BotCommand = "Surrender";
