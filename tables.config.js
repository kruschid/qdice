module.exports = {
  tables: [
    {
      tag: "Planeta",
      name: "Planeta",
      mapName: "Planeta",
      playerSlots: 8,
      startSlots: 8,
      points: 0,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: false,
        startingCapitals: false,
        readySlots: null,
        turnSeconds: null,
      },
    },
    {
      tag: "España",
      name: "España",
      mapName: "Serrano",
      playerSlots: 7,
      startSlots: 7,
      points: 0,
      stackSize: 8,
      params: {
        noFlagRounds: 2,
        botLess: false,
        startingCapitals: false,
        readySlots: null,
        turnSeconds: null,
      },
    },
    {
      tag: "Lagos",
      name: "Lagos",
      mapName: "DeLucía",
      playerSlots: 8,
      startSlots: 4,
      points: 0,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: true,
        startingCapitals: true,
        readySlots: 2,
        turnSeconds: 60,
      },
    },
    {
      tag: "Polo",
      name: "Polo",
      mapName: "Melchor",
      playerSlots: 3,
      startSlots: 2,
      points: 100,
      stackSize: 8,
      params: {
        noFlagRounds: 2,
        botLess: true,
        startingCapitals: false,
        readySlots: 2,
        turnSeconds: null,
      },
    },
    // {
    // tag: "Miño",
    // name: "Miño",
    // mapName: "Miño",
    // playerSlots: 5,
    // startSlots: 2,
    // points: 0,
    // stackSize: 4,
    // params: {
    // noFlagRounds: 0,
    // botLess: true,
    // },
    // },
    {
      tag: "Arabia",
      name: "Arabia",
      mapName: "Sabicas",
      playerSlots: 8,
      startSlots: 4,
      points: 500,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: true,
        startingCapitals: true,
        readySlots: 2,
        turnSeconds: null,
      },
    },
    {
      tag: "Europa",
      name: "Europa",
      mapName: "Montoya",
      playerSlots: 8,
      startSlots: 8,
      points: 200,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: false,
        startingCapitals: true,
        readySlots: null,
        turnSeconds: null,
      },
    },
    {
      tag: "Hourly2000",
      name: "Hourly2000",
      mapName: "Sabicas",
      playerSlots: 8,
      startSlots: 3,
      points: 500,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: true,
        startingCapitals: true,
        readySlots: null,
        turnSeconds: 60,
        tournament: {
          frequency: "hourly",
          prize: 2000,
          fee: 200,
        },
      },
    },
    {
      tag: "5MinuteFix",
      name: "5MinuteFix",
      mapName: "DeLucía",
      playerSlots: 8,
      startSlots: 2,
      points: 200,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: true,
        startingCapitals: true,
        readySlots: null,
        turnSeconds: 45,
        tournament: {
          frequency: "5minutely",
          prize: 1000,
          fee: 100,
        },
      },
    },
    {
      tag: "Daily10k",
      name: "Daily10k",
      mapName: "Planeta",
      playerSlots: 8,
      startSlots: 4,
      points: 1000,
      stackSize: 8,
      params: {
        noFlagRounds: 5,
        botLess: true,
        startingCapitals: true,
        readySlots: null,
        turnSeconds: 60,
        tournament: {
          frequency: "daily",
          prize: 10000,
          fee: 500,
        },
      },
    },
  ],
};
