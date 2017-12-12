module Game.View exposing (view)

import Game.Types exposing (PlayerAction(..))
import Game.Chat
import Html
import Html.Attributes exposing (class, style)
import Time exposing (inMilliseconds)
import Material
import Material.Options as Options
import Material.Elevation as Elevation
import Material.Chip as Chip
import Material.Button as Button
import Material.Icon as Icon
import Material.Footer as Footer
import Material.List as Lists
import Types exposing (Model, Msg(..))
import Tables exposing (Table, tableList)
import Board
import Backend.Types exposing (ConnectionStatus(..))


view : Model -> Html.Html Types.Msg
view model =
    let
        board =
            Board.view model.game.board
                |> Html.map BoardMsg
    in
        Html.div [ class "edGame" ]
            [ header model
            , board
            , Html.div [ class "edPlayerChips" ] <| List.indexedMap (playerChip model) model.game.players
            , boardHistory model
            , footer model
            ]


header : Model -> Html.Html Types.Msg
header model =
    Html.div [ class "edGameHeader" ]
        [ Html.span [ class "edGameHeader__chip" ]
            [ Html.text "Table "
            , Html.span [ class "edGameHeader__chip--strong" ]
                [ Html.text <| toString model.game.table
                ]
            ]
        , Html.span [ class "edGameHeader__chip" ]
            [ Html.text ", "
            , Html.span [ class "edGameHeader__chip--strong" ]
                [ Html.text <| toString model.game.playerSlots
                ]
            , Html.text " player game is "
            , Html.span [ class "edGameHeader__chip--strong" ]
                [ Html.text <| toString model.game.status
                ]
            ]
        , case model.backend.status of
            Online ->
                case model.user of
                    Types.Anonymous ->
                        Html.text ""

                    Types.Logged user ->
                        seatButton model

            _ ->
                Html.text ""
        ]


seatButton : Model -> Html.Html Types.Msg
seatButton model =
    let
        ( label, action ) =
            (if isPlayerInGame model then
                (if model.game.status == Game.Types.Playing then
                    ( "Sit out", SitOut )
                 else
                    ( "Leave game", Leave )
                )
             else
                ( "Join game", Join )
            )
    in
        Button.render
            Types.Mdl
            [ 0 ]
            model.mdl
            [ Button.raised
            , Button.colored
            , Button.ripple
            , Options.cs "edGameHeader__button"
            , Options.onClick <| GameCmd action
            ]
            [ Html.text label ]


playerChip : Model -> Int -> Game.Types.Player -> Html.Html Types.Msg
playerChip model index player =
    Options.div
        [ Options.cs ("edPlayerChip edPlayerChip--" ++ (toString player.color))
        , if index == model.game.turnIndex then
            Elevation.e6
          else
            Elevation.e2
        ]
        [ Html.img
            [ class "edPlayerChip__picture"
            , style
                [ ( "background-image", ("url(" ++ player.picture ++ ")") )
                , ( "background-size", "cover" )
                ]
            ]
            []
        , Html.div [ class "edPlayerChip__name" ] [ Html.text player.name ]
        , Html.div []
            [ playerChipProgress model index
            ]
        ]


playerChipProgress model index =
    let
        hasTurn =
            index == model.game.turnIndex

        progress =
            (turnProgress model) * 100

        progressStep =
            floor (progress / 10) * 10
    in
        Html.div
            [ class ("edPlayerChip__progress edPlayerChip__progress--" ++ (toString progressStep))
            , style
                [ ( "width"
                  , (if hasTurn then
                        (toString progress) ++ "%"
                     else
                        "0%"
                    )
                  )
                ]
            ]
            []


turnProgress : Model -> Float
turnProgress model =
    let
        turnTime =
            toFloat model.game.turnDuration

        timestamp =
            inMilliseconds model.time / 1000

        turnStarted =
            toFloat model.game.turnStarted
    in
        max 0.05 <|
            min 1 <|
                (turnTime - (timestamp - turnStarted))
                    / turnTime



--Chip.span [ Options.cs ("edPlayerChip edPlayerChip--" ++ (toString player.color)) ]
--[ Chip.contact Html.img
--[ Options.css "background-image" ("url(" ++ player.picture ++ ")")
--, Options.css "background-size" "cover"
--]
--[]
--, Chip.content []
--[ Html.text <| player.name ]
--]


boardHistory : Model -> Html.Html Types.Msg
boardHistory model =
    Html.div []
        [ Game.Chat.chatBox model ]


footer : Model -> Html.Html Types.Msg
footer model =
    Footer.mini []
        { left =
            Footer.left [] (statusMessage model.backend.status)
        , right = Footer.right [] (listOfTables model tableList)
        }


listOfTables : Model -> List Table -> List (Footer.Content Types.Msg)
listOfTables model tables =
    [ Footer.html <|
        Lists.ul [] <|
            List.indexedMap
                (\i ->
                    \table ->
                        Lists.li [ Lists.withSubtitle ]
                            [ Lists.content []
                                [ Html.text <| toString table
                                , Lists.subtitle [] [ Html.text "0 playing" ]
                                ]
                            , goToTableButton model table i
                            ]
                )
                tables
    ]


goToTableButton : Model -> Table -> Int -> Html.Html Types.Msg
goToTableButton model table i =
    Button.render Types.Mdl
        [ i ]
        model.mdl
        [ Button.icon
        , Options.onClick (Types.NavigateTo <| Types.GameRoute table)
        ]
        [ Icon.i "chevron_right" ]


statusMessage : ConnectionStatus -> List (Footer.Content Types.Msg)
statusMessage status =
    let
        message =
            case status of
                Reconnecting attempts ->
                    case attempts of
                        1 ->
                            "Reconnecting..."

                        count ->
                            "Reconnecting... (" ++ (toString attempts) ++ " retries)"

                _ ->
                    toString status

        icon =
            case status of
                Offline ->
                    "signal_wifi_off"

                Connecting ->
                    "wifi"

                Reconnecting _ ->
                    "wifi"

                Subscribing ->
                    "perm_scan_wifi"

                Online ->
                    "network_wifi"
    in
        [ Footer.html <| Icon.i icon
          --, Footer.html <| Html.text message
        ]


isPlayerInGame : Model -> Bool
isPlayerInGame model =
    case model.user of
        Types.Anonymous ->
            False

        Types.Logged user ->
            List.map (.id) model.game.players
                |> List.any (\id -> id == user.id)
