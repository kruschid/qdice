module Game.View exposing (view)

import Array
import Awards
import Backend.Types exposing (ConnectionStatus(..))
import Board
import Board.Colors
import Board.Die
import Color
import Comments
import Game.Chat
import Game.Footer
import Game.PlayerCard as PlayerCard exposing (TurnPlayer, playerPicture)
import Game.State exposing (canSelect)
import Game.Types exposing (ChatLogEntry(..), GameStatus(..), Msg(..), Player, PlayerAction(..), RollUI, isBot)
import Helpers exposing (dataTestId, pointsSymbol, pointsToNextLevel)
import Html exposing (..)
import Html.Attributes exposing (class, disabled, height, href, src, style, width)
import Html.Events exposing (onClick)
import Html.Lazy
import Icon
import LeaderBoard.View
import MyProfile.MyProfile
import MyProfile.Types
import Ordinal exposing (ordinal)
import Routing.String exposing (routeToString)
import Time exposing (Posix, posixToMillis)
import Tournaments exposing (tournamentTime)
import Types exposing (AuthNetwork(..), DialogType(..), GamesSubRoute(..), Model, Msg(..), PushEvent(..), Route(..), SessionPreference(..), User(..))


view : Model -> Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                (Maybe.andThen
                    (\emoji ->
                        if canSelect model.game emoji then
                            model.game.hovered
                            -- for Html.lazy ref-check

                        else
                            Nothing
                    )
                    model.game.hovered
                )
                model.game.boardOptions
                (List.map
                    (\p ->
                        ( p.color, p.picture )
                    )
                    model.game.players
                )
                |> Html.map BoardMsg
    in
    div [ class "edMainScreen" ] <|
        [ div [ class "edGameBoardWrapper" ] <|
            if not model.game.params.twitter then
                (if not model.fullscreen then
                    [ tableInfo model ]

                 else
                    [ button [ class "edGameStatus__button edGameFullscreenButton edGameStatus__button--landscape edButton--icon", onClick RequestFullscreen ] [ Icon.icon "zoom_out_map" ]
                    ]
                )
                    ++ [ header model
                       , board
                       , if model.game.boardOptions.diceVisible then
                            lastRoll model.game.lastRoll

                         else
                            text ""
                       , sitInModal model
                       , boardFooter model
                       , tableDetails model
                       ]

            else
                [ header model
                , board
                , boardFooter model
                ]
        ]
            ++ (if not model.fullscreen && not model.game.params.twitter then
                    div
                        [ class <|
                            "edGame__meta cartonCard"
                                ++ (if model.game.expandChat then
                                        " edGame__meta--open"

                                    else
                                        ""
                                   )
                        ]
                        [ gameChat model
                        , gameLog model
                        , div
                            [ class "edGame__meta__expander"
                            , onClick <| ExpandChats
                            ]
                            [ Icon.iconSized 10 "more_horiz" ]
                        ]
                        :: Game.Footer.footer model
                        ++ [ div [ class "edBoxes cartonCard" ] <|
                                [ Html.Lazy.lazy3 playerBox model.user model.myProfile model.sessionPreferences
                                , Html.Lazy.lazy leaderboardBox model.leaderBoard
                                ]
                           , div [ class "cartonCard cartonCard--padded" ] <|
                                case model.game.table of
                                    Just table ->
                                        [ Html.Lazy.lazy4 Comments.view model.zone model.user model.comments <| Comments.tableComments table ]

                                    Nothing ->
                                        []
                           ]

                else
                    []
               )


header : Model -> Html.Html Types.Msg
header model =
    div [ class "edGameHeader" ]
        [ playerBar 4 model
        ]


boardFooter : Model -> Html.Html Types.Msg
boardFooter model =
    let
        toolbar =
            if model.screenshot || model.game.params.twitter then
                []

            else
                [ div [ class "edGameBoardFooter__content" ] <| seatButtons model
                ]
    in
    div [ class "edGameBoardFooter" ] <|
        playerBar 0 model
            :: toolbar
            ++ [ Html.Lazy.lazy2 chatOverlay model.fullscreen model.game.chatOverlay ]


chatOverlay : Bool -> Maybe ( Time.Posix, ChatLogEntry ) -> Html Msg
chatOverlay fullscreen overlay =
    if not fullscreen then
        text ""

    else
        case overlay of
            Just ( _, entry ) ->
                div
                    [ class "edChatOverlay" ]
                    [ Game.Chat.chatLine entry
                    ]

            Nothing ->
                text ""


playerBar : Int -> Model -> Html Msg
playerBar dropCount model =
    div [ class "edPlayerChips" ] <|
        List.map (PlayerCard.view model.game.status) <|
            List.take 4 <|
                List.drop dropCount <|
                    sortedPlayers model


sortedPlayers : Model -> List TurnPlayer
sortedPlayers model =
    let
        acc : Array.Array TurnPlayer
        acc =
            Array.initialize 8 (\i -> { player = Nothing, index = i, turn = Nothing, isUser = False })

        fold : ( Int, Player ) -> Array.Array TurnPlayer -> Array.Array TurnPlayer
        fold =
            \( i, p ) ->
                \array ->
                    Array.set (Board.Colors.colorIndex p.color - 1)
                        { player = Just p
                        , index = i
                        , turn =
                            if i == model.game.turnIndex then
                                let
                                    turnTime =
                                        Maybe.withDefault
                                            model.settings.turnSeconds
                                            model.game.params.turnSeconds
                                            |> toFloat
                                in
                                Just <| PlayerCard.turnProgress turnTime model.time model.game.turnStart

                            else
                                Nothing
                        , isUser = model.game.player |> Maybe.map ((==) p) |> Maybe.withDefault False
                        }
                        array
    in
    List.foldl
        fold
        acc
        (List.indexedMap Tuple.pair model.game.players)
        |> Array.toList


seatButtons : Model -> List (Html.Html Types.Msg)
seatButtons model =
    case model.backend.status of
        Online _ _ ->
            onlineButtons model

        _ ->
            findTableButton model
                ++ [ button [ class "edButton edGameHeader__button", disabled True ] [ Icon.icon "signal_wifi_off" ]
                   ]


joinButton : String -> Types.Msg -> Html.Html Types.Msg
joinButton label msg =
    button
        [ class "edButton edGameHeader__button"
        , onClick msg
        , dataTestId "button-seat"
        ]
        [ text label ]


onlineButtons : Model -> List (Html.Html Types.Msg)
onlineButtons model =
    if model.game.status /= Game.Types.Playing then
        case model.game.player of
            Just player ->
                case model.game.params.tournament of
                    Just _ ->
                        []

                    Nothing ->
                        [ label
                            [ class <|
                                "edCheckbox edGameHeader__checkbox"
                                    ++ (if Maybe.withDefault player.ready model.game.isReady then
                                            " edGameHeader__checkbox--checked"

                                        else
                                            ""
                                       )
                            , onClick <| GameCmd <| ToggleReady <| not <| Maybe.withDefault player.ready model.game.isReady
                            , dataTestId "check-ready"
                            ]
                            [ Icon.icon <|
                                if Maybe.withDefault player.ready model.game.isReady then
                                    "check_box"

                                else
                                    "check_box_outline_blank"
                            , text "Ready"
                            ]
                        , joinButton "Leave" <| GameCmd Leave
                        ]

            Nothing ->
                case model.user of
                    Types.Anonymous ->
                        case model.game.params.tournament of
                            Just _ ->
                                findTableButton model
                                    ++ [ button
                                            [ class "edButton edGameHeader__button"
                                            , onClick <| ShowLogin Types.LoginShow
                                            ]
                                            [ text "Log in to check your eligibility" ]
                                       ]

                            Nothing ->
                                findTableButton model
                                    ++ [ joinButton "Play now" <| ShowLogin Types.LoginShowJoin ]

                    Types.Logged user ->
                        case model.game.params.tournament of
                            Just tournament ->
                                findTableButton model
                                    ++ (if user.points >= model.game.points then
                                            if user.points >= tournament.fee then
                                                [ joinButton
                                                    ("Join game for "
                                                        ++ (if tournament.fee > 0 then
                                                                Helpers.formatPoints tournament.fee

                                                            else
                                                                "free"
                                                           )
                                                    )
                                                  <|
                                                    if tournament.fee > 0 then
                                                        ShowDialog <|
                                                            Confirm
                                                                (\model_ ->
                                                                    ( "Enter game for "
                                                                        ++ (if tournament.fee > 0 then
                                                                                Helpers.formatPoints tournament.fee

                                                                            else
                                                                                "free"
                                                                           )
                                                                        ++ "?"
                                                                    , [ text <|
                                                                            "The prize for 1st is "
                                                                                ++ Helpers.formatPoints tournament.prize
                                                                                ++ "."
                                                                                ++ """
  You will be sat and cannot leave the game until it starts.

  You can meanwhile play on other tables.

  If minimum player requirements is not met, the fee will be returned.

  """
                                                                                ++ (case model_.game.gameStart of
                                                                                        Nothing ->
                                                                                            "Remember to come back at the game start time."

                                                                                        Just timestamp ->
                                                                                            "Remember to come back at "
                                                                                                ++ tournamentTime model_.zone model_.time timestamp
                                                                                                ++ """.
  """
                                                                                   )

                                                                      -- , a [ href "#" ] [ text "Enable notifications" ]
                                                                      , button [ onClick RequestNotifications ]
                                                                            [ text "Enable notifications"
                                                                            , Icon.icon "sms"
                                                                            ]
                                                                      , text " ...to get an alert at game start!"
                                                                      ]
                                                                    )
                                                                )
                                                            <|
                                                                GameCmd Join

                                                    else
                                                        GameCmd Join
                                                ]

                                            else
                                                [ text <|
                                                    "Game entry fee is "
                                                        ++ (if tournament.fee > 0 then
                                                                Helpers.formatPoints tournament.fee

                                                            else
                                                                "free"
                                                           )
                                                ]

                                        else
                                            [ text <| "Table has minimum points of " ++ String.fromInt model.game.points ]
                                       )

                            Nothing ->
                                findTableButton model
                                    ++ (if model.game.points == 0 || user.points >= model.game.points then
                                            [ joinButton "Join" <| GameCmd Join ]

                                        else
                                            [ text <| "Table has minimum points of " ++ String.fromInt model.game.points ]
                                       )

    else
        case model.game.player of
            Nothing ->
                if model.game.players |> List.any isBot then
                    case model.user of
                        Types.Anonymous ->
                            [ joinButton "Join & Take over a bot" <| ShowLogin Types.LoginShowJoin ]

                        Types.Logged user ->
                            if user.points >= model.game.points then
                                [ joinButton "Join & Take over a bot" <| GameCmd Join ]

                            else
                                [ text <| "Table has minimum points of " ++ String.fromInt model.game.points ]

                else
                    []

            Just player ->
                let
                    canFlag =
                        canPlayerFlag model.game.roundCount
                            model.game.params.noFlagRounds
                            model.game.flag
                            player

                    sitButton =
                        if model.game.isPlayerOut then
                            [ button
                                [ class <|
                                    "edButton edGameHeader__button"
                                        ++ (if canFlag then
                                                " edGameHeader__button--left"

                                            else
                                                ""
                                           )
                                , onClick <| GameCmd SitIn
                                , dataTestId "button-seat"
                                ]
                                [ text "Sit in!" ]
                            ]

                        else
                            [ button
                                [ class <|
                                    "edButton edGameHeader__button"
                                        ++ (if not canFlag then
                                                " edGameHeader__button--left"

                                            else
                                                ""
                                           )
                                , onClick <| GameCmd SitOut
                                , dataTestId "button-seat"
                                ]
                                [ text "Leave game" ]
                            ]

                    checkbox =
                        if canFlag then
                            [ label
                                [ class "edCheckbox edGameHeader__checkbox edGameHeader__button--left"
                                , onClick <| GameCmd <| Flag player.gameStats.position
                                , dataTestId "check-flag"
                                ]
                                [ Icon.icon "flag"
                                , text <|
                                    if player.gameStats.position == List.length model.game.players then
                                        "Surrender"

                                    else
                                        " " ++ ordinal player.gameStats.position
                                ]
                            ]

                        else
                            []

                    turnButton =
                        [ button
                            [ class <|
                                if model.game.hasTurn && not model.game.canMove then
                                    "edButton edGameHeader__button edGameHeader__button--flash"

                                else
                                    "edButton edGameHeader__button"
                            , onClick <| GameCmd EndTurn
                            , dataTestId "button-seat"
                            , disabled <| not model.game.hasTurn
                            ]
                            [ text "End turn" ]
                        ]
                in
                sitButton ++ checkbox ++ turnButton


gameLog : Model -> Html.Html Types.Msg
gameLog model =
    Game.Chat.gameBox
        model.game.gameLog
    <|
        "gameLog-"
            ++ Maybe.withDefault "NOTABLE" model.game.table


gameChat : Model -> Html.Html Types.Msg
gameChat model =
    div [ class "chatboxContainer" ]
        [ Game.Chat.chatBox
            model.game.chatInput
            model.game.chatLog
          <|
            "chatLog-"
                ++ Maybe.withDefault "NOTABLE" model.game.table
        ]


sitInModal : Model -> Html.Html Types.Msg
sitInModal model =
    div
        [ if model.game.player /= Nothing && model.game.isPlayerOut then
            style "" ""

          else
            style "display" "none"
        , class "edGame__SitInModal"
        , Html.Events.onClick <| GameCmd SitIn
        ]
        [ button
            [ onClick <| GameCmd SitIn
            ]
            [ text "Sit in!" ]
        ]


tableInfo : Model -> Html Types.Msg
tableInfo model =
    div [ class "edGameStatus" ] <|
        [ a
            [ class "edLogo"
            , href <| routeToString model.zip <| Types.HomeRoute
            ]
            [ img [ src "quedice.svg", width 28, height 28, class "edLogo_img" ] [] ]
        ]
            ++ (case model.game.table of
                    Just table ->
                        case model.game.currentGame of
                            Just id ->
                                [ span [ class "edGameStatus__chip" ] [ text <| table ++ "\u{00A0}" ]
                                , a
                                    [ href <|
                                        routeToString False <|
                                            GamesRoute <|
                                                GameId table id
                                    , dataTestId "current-game-id"
                                    ]
                                    [ text <|
                                        "game #"
                                            ++ String.fromInt id
                                    ]
                                , span
                                    [ dataTestId "game-round"
                                    ]
                                    [ text <|
                                        "\u{00A0}round "
                                            ++ String.fromInt model.game.roundCount
                                    ]
                                ]

                            Nothing ->
                                [ a
                                    [ class "edGameStatus__chip"
                                    , href <| routeToString False <| GamesRoute <| GamesOfTable table
                                    , dataTestId "table-games-link"
                                    ]
                                    [ text table
                                    ]
                                ]

                    Nothing ->
                        []
               )
            ++ [ div [ class "edGameStatus__buttons" ]
                    [ button
                        [ class "edGameStatus__button edButton--icon"
                        , onClick <| GameMsg <| ToggleDiceVisible <| not model.game.boardOptions.diceVisible
                        ]
                        [ Icon.icon <|
                            if model.game.boardOptions.diceVisible then
                                "visibility"

                            else
                                "visibility_off"
                        ]
                    , button
                        [ class "edGameStatus__button edButton--icon", onClick <| SetSessionPreference <| Muted <| not model.sessionPreferences.muted ]
                        [ Icon.icon <|
                            if model.sessionPreferences.muted then
                                "volume_off"

                            else
                                "volume_up"
                        ]
                    ]
               ]


tableDetails : Model -> Html Types.Msg
tableDetails model =
    div [ class "edGameDetails" ] <|
        case model.game.table of
            Just _ ->
                case model.game.status of
                    Playing ->
                        []

                    _ ->
                        [ div [ class "edGameStatus__chip" ] <|
                            [ text <|
                                if model.game.playerSlots == 0 then
                                    "∅"

                                else
                                    String.fromInt model.game.playerSlots
                            , text " players"
                            , if model.game.params.botLess then
                                text ", no bots"

                              else if not <| List.any (.botCount >> (/=) 0) model.tableList then
                                text ", bots will join"

                              else
                                text ", bots will join"
                            ]
                                ++ (if model.game.params.tournament == Nothing then
                                        case model.game.gameStart of
                                            Nothing ->
                                                [ text <|
                                                    ", starts with "
                                                        ++ String.fromInt model.game.startSlots
                                                        ++ " players"
                                                        ++ (case model.game.params.readySlots of
                                                                Just n ->
                                                                    " or when " ++ String.fromInt n ++ " are ready"

                                                                Nothing ->
                                                                    ""
                                                           )
                                                ]

                                            Just timestamp ->
                                                [ text ", starting in"
                                                , span [ class "edGameStatus__chip--strong" ] [ text <| "\u{00A0}" ++ String.fromInt ((round <| toFloat timestamp - ((toFloat <| posixToMillis model.time) / 1000)) + 1) ++ "s" ]
                                                ]

                                    else
                                        []
                                   )
                        ]
                            ++ (case model.game.params.tournament of
                                    Nothing ->
                                        []

                                    Just tournament ->
                                        [ div [ class "edGameStatus__chip" ] <|
                                            case model.game.gameStart of
                                                Nothing ->
                                                    [ text <| "Game scheduled " ++ tournament.frequency ]

                                                Just timestamp ->
                                                    [ text <| "Game scheduled at "
                                                    , span [ class "edGameStatus__chip--strong" ]
                                                        [ text <| tournamentTime model.zone model.time timestamp ]
                                                    ]
                                        ]
                               )
                            ++ (case model.game.params.turnSeconds of
                                    Just n ->
                                        [ div [ class "edGameStatus__chip" ] [ text <| "Turn timeout is " ++ turnTimeDisplay n ] ]

                                    Nothing ->
                                        []
                               )
                            ++ (case model.game.params.tournament of
                                    Nothing ->
                                        []

                                    Just tournament ->
                                        [ div [ class "edGameStatus__chip" ] <|
                                            [ text <| "Game prize is " ++ Helpers.formatPoints tournament.prize ]
                                        ]
                               )

            Nothing ->
                []


playerBox : User -> MyProfile.Types.MyProfileModel -> Types.SessionPreferences -> Html Msg
playerBox user myProfile sessionPreferences =
    div [ class "edBox edPlayerBox" ]
        [ div [ class "edBox__header" ] [ text "Profile " ]
        , div [ class "edBox__inner" ] <|
            case user of
                Logged logged ->
                    [ div [ class "edPlayerBox__Picture" ] [ playerPicture "medium" logged.picture logged.name ]
                    , div [ class "edPlayerBox__Name" ]
                        [ a [ href <| routeToString False <| ProfileRoute logged.id logged.name ]
                            [ text logged.name
                            ]
                        ]
                    , div [ class "edPlayerBox__stat" ] [ text "Level: ", text <| String.fromInt logged.level ++ "▲" ]
                    , if List.length logged.awards > 0 then
                        div [ class "edPlayerBox__awards" ] <| Awards.awardsShortList 20 logged.awards

                      else
                        text ""
                    , div [ class "edPlayerBox__stat" ] [ text "Points: ", text <| String.fromInt logged.points ++ pointsSymbol ]
                    , div [ class "edPlayerBox__stat" ]
                        [ text <| (String.fromInt <| pointsToNextLevel logged.level logged.levelPoints) ++ pointsSymbol
                        , text " points to next level"
                        ]
                    , div [ class "edPlayerBox__stat" ] [ text "Monthly rank: ", text <| ordinal logged.rank ]
                    , div [ class "edPlayerBox__settings" ] <|
                        [ case logged.networks of
                            [] ->
                                div [ class "edPlayerBox__addNetworks" ] <|
                                    [ h3 [ style "color" "red" ]
                                        [ Icon.spinning "warning"
                                        , text " Account has no login!"
                                        ]
                                    , p []
                                        [ text "Your player has no login. You could lose all your points, level and rank anytime you clear your browser's cache or something."
                                        , br [] []
                                        , text "To prevent this, you should add one of the following logins to your account:"
                                        ]
                                    ]
                                        ++ MyProfile.MyProfile.addNetworks
                                            myProfile
                                            logged

                            _ ->
                                text ""
                        , div []
                            [ a [ href "/me" ]
                                [ text "Go to my Account & Settings"
                                ]
                            ]
                        , if not sessionPreferences.notificationsEnabled then
                            p [] [ text "You can get notifications when the tab is in background and it's your turn or the game starts:" ]

                          else
                            text ""
                        , if not sessionPreferences.notificationsEnabled then
                            div []
                                [ button [ onClick RequestNotifications ]
                                    [ text "Enable notifications"
                                    , Icon.icon "sms"
                                    ]
                                ]

                          else
                            text ""
                        ]
                    ]

                Anonymous ->
                    [ div [] [ text "You're not logged in." ]
                    , button
                        [ onClick <| ShowLogin Types.LoginShow
                        ]
                        [ text "Pick a username" ]
                    ]
        ]


leaderboardBox : Types.LeaderBoardModel -> Html Msg
leaderboardBox leaderBoard =
    div [ class "edBox edLeaderboardBox" ]
        [ div [ class "edBox__header" ]
            [ a
                [ href "/leaderboard"
                ]
                [ text "Leaderboard" ]
            , text <| " for " ++ leaderBoard.month
            ]
        , div [ class "edBox__inner" ]
            [ LeaderBoard.View.table 10 leaderBoard.top ]
        ]


turnTimeDisplay : Int -> String
turnTimeDisplay seconds =
    let
        ( value, unit ) =
            Helpers.timeUnits seconds
    in
    String.fromInt value
        ++ " "
        ++ (case value of
                1 ->
                    unit

                _ ->
                    unit ++ "s"
           )


canPlayerFlag : Int -> Int -> Maybe Int -> Player -> Bool
canPlayerFlag roundCount noFlagRounds uiFlagged player =
    (roundCount > noFlagRounds)
        && player.gameStats.position
        > 1
        && (case player.flag of
                Just f ->
                    f < player.gameStats.position

                Nothing ->
                    uiFlagged == Nothing
           )


findTableButton : Model -> List (Html Msg)
findTableButton model =
    if
        (List.length model.game.players
            == 0
            && model.game.table
            /= Just "5MinuteFix"
            -- && List.any (.playerCount >> (/=) 0) model.tableList
            && model.user
            /= Types.Anonymous
        )
            || (Maybe.map .points model.game.player |> Maybe.withDefault 1000000)
            < model.game.points
    then
        [ button
            [ class <|
                "edButton edGameHeader__button edGameHeader__button--left"
            , onClick <| FindGame model.game.table
            , dataTestId "button-find"
            ]
            [ text "Find players" ]
        ]

    else
        []


lastRoll : Maybe RollUI -> Html msg
lastRoll mRoll =
    div [ class "edRoll" ] <|
        case mRoll of
            Just roll ->
                [ div
                    [ class "edRoll__from"
                    , style "background-color" <|
                        (Board.Colors.base (Tuple.first roll.from)
                            |> Board.Colors.cssRgb
                        )
                    ]
                  <|
                    List.map Board.Die.rollDie <|
                        Tuple.second roll.from
                , div
                    [ class "edRoll__to"
                    , style "background-color" <|
                        (Board.Colors.base (Tuple.first roll.to)
                            |> Board.Colors.cssRgb
                        )
                    ]
                  <|
                    List.map Board.Die.rollDie <|
                        Tuple.second roll.to
                ]

            Nothing ->
                []
