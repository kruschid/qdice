module Game.State exposing (..)

import Task
import Game.Types exposing (..)
import Types exposing (Model, Msg(..), User(Anonymous))
import Board
import Board.State
import Board.Types
import Maps exposing (load)
import Land exposing (Color)
import Tables exposing (Table(..))
import Backend
import Backend.Types exposing (Topic(..))
import Helpers exposing (indexOf, playSound)


init : Maybe Types.Model -> Table -> ( Game.Types.Model, List (Cmd Types.Msg) )
init model table =
    let
        ( map, mapCmd ) =
            Maps.load table

        board =
            Board.init map

        players =
            []

        cmds =
            mapCmd
                :: case model of
                    Just model ->
                        [ Backend.gameCommand model.backend table Enter
                        , Backend.publish <| TableMsg model.game.table <| Backend.Types.Leave <| Types.getUsername model
                        , Backend.publish <| TableMsg table <| Backend.Types.Join <| Types.getUsername model
                        ]

                    Nothing ->
                        []
    in
        ( { table = table
          , board = board
          , players = players
          , player = Nothing
          , status = Paused
          , playerSlots = 2
          , turnDuration = 10
          , turnIndex = -1
          , hasTurn = False
          , turnStarted = -1
          , chatInput = ""
          , chatBoxId = ("chatbox-" ++ toString table)
          }
        , cmds
        )


setter : Types.Model -> (Game.Types.Model -> Game.Types.Model) -> Types.Model
setter model setter =
    { model | game = (setter model.game) }


updateCommandResponse : Table -> PlayerAction -> Types.Model -> ( Types.Model, Cmd Msg )
updateCommandResponse table action model =
    model ! []


setTable : Game.Types.Model -> Table -> Game.Types.Model
setTable model table =
    let
        board =
            Board.init <| Tuple.first <| Maps.load table
    in
        { model | table = table, board = board }


updateTableStatus : Types.Model -> Game.Types.TableStatus -> ( Types.Model, Cmd Msg )
updateTableStatus model status =
    let
        game =
            model.game

        player =
            case model.user of
                Types.Anonymous ->
                    Nothing

                Types.Logged user ->
                    List.head <| List.filter (\p -> p.id == user.id) status.players

        hasTurn =
            case player of
                Nothing ->
                    False

                Just player ->
                    indexOf player status.players == status.turnIndex

        hasLostTurn =
            case player of
                Nothing ->
                    False

                Just player ->
                    hasTurn
                        == False
                        && indexOf player game.players
                        == game.turnIndex

        move =
            if hasLostTurn then
                Just Board.Types.Idle
            else
                Nothing

        board_ =
            Board.State.updateLands model.game.board status.lands move

        game_ =
            { game
                | players = status.players
                , player = player
                , status = status.status
                , turnIndex = status.turnIndex
                , hasTurn = hasTurn
                , turnStarted = status.turnStarted
                , board = board_
            }
    in
        { model | game = game_ } ! []


showRoll : Types.Model -> Roll -> ( Types.Model, Cmd Msg )
showRoll model roll =
    let
        board_ =
            Board.State.updateLands model.game.board [] <| Just Board.Types.Idle

        game =
            model.game

        game_ =
            { game | board = board_ }

        soundName =
            if List.sum roll.from.roll > List.sum roll.to.roll then
                "rollSuccess"
            else
                "rollDefeat"
    in
        ( { model | game = game_ }, playSound soundName )


clickLand : Types.Model -> Land.Land -> ( Types.Model, Cmd Types.Msg )
clickLand model land =
    case model.game.player of
        Nothing ->
            ( model, Cmd.none )

        Just player ->
            let
                ( move, cmd ) =
                    if not model.game.hasTurn then
                        ( model.game.board.move, Cmd.none )
                    else
                        case model.game.board.move of
                            Board.Types.Idle ->
                                if land.color == player.color then
                                    ( Board.Types.From land, Cmd.none )
                                else
                                    ( Board.Types.Idle, Cmd.none )

                            Board.Types.From from ->
                                if land == from then
                                    ( Board.Types.Idle, Cmd.none )
                                else if land.color == player.color then
                                    ( model.game.board.move, Cmd.none )
                                else if not <| Land.isBordering land from then
                                    ( model.game.board.move, Cmd.none )
                                else
                                    let
                                        gameCmd =
                                            Backend.attack model.backend model.game.table from.emoji land.emoji
                                    in
                                        ( Board.Types.FromTo from land, Cmd.batch [ playSound "diceroll", gameCmd ] )

                            Board.Types.FromTo from to ->
                                ( model.game.board.move, Cmd.none )

                game =
                    model.game

                board =
                    game.board

                board_ =
                    { board | move = move }

                game_ =
                    { game | board = board_ }
            in
                { model | game = game_ } ! [ cmd ]



--updateClickLand : Types.Model -> Land.Land -> Types.Model
--updateClickLand model land =
--model
