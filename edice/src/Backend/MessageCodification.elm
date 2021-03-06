module Backend.MessageCodification exposing (ChatMessage, decodeDirection, decodeTopicMessage, encodeTopic)

import Backend.Decoding exposing (..)
import Backend.Types exposing (..)
import Json.Decode as Dec exposing (..)
import Tables exposing (Table)
import Types exposing (Msg(..))


type alias ChatMessage =
    { username : String
    , message : String
    }


{-| Maybe Table because it might be a table message for this client only
-}
decodeTopicMessage : Topic -> String -> Result String Msg
decodeTopicMessage topic message =
    case topic of
        Client _ ->
            case decodeString (field "table" string) message of
                Err _ ->
                    decodeClientMessage message

                Ok tableName ->
                    decodeTableMessage tableName message

        AllClients ->
            case decodeString (field "type" Dec.string) message of
                Err err ->
                    Err <| decodeErrorToString "AllClients" "type" err

                Ok mtype ->
                    case mtype of
                        "tables" ->
                            case decodeString (field "payload" <| Dec.list tableInfoDecoder) message of
                                Ok tables ->
                                    Ok <| AllClientsMsg <| TablesInfo tables

                                Err err ->
                                    Err <| decodeErrorToString "AllClients" mtype err

                        "sigint" ->
                            Ok <| AllClientsMsg <| SigInt

                        "toast" ->
                            case decodeString (field "payload" <| Dec.string) message of
                                Ok toastMessage ->
                                    Ok <| AllClientsMsg <| Toast toastMessage

                                Err err ->
                                    Err <| decodeErrorToString "AllClients" mtype err

                        "online" ->
                            case
                                decodeString
                                    (field "payload" <|
                                        Dec.map2 Tuple.pair
                                            (field "version" Dec.string)
                                            (field "message" Dec.string)
                                    )
                                    message
                            of
                                Ok ( version, toastMessage ) ->
                                    Ok <| AllClientsMsg <| ServerOnline version toastMessage

                                Err err ->
                                    Err <| decodeErrorToString "AllClients" mtype err

                        _ ->
                            Err <| "unknown global message type \"" ++ mtype ++ "\""

        Tables table _ ->
            decodeTableMessage table message


decodeTableMessage : Table -> String -> Result String Msg
decodeTableMessage table message =
    case decodeString (field "type" Dec.string) message of
        Err err ->
            Err <| decodeErrorToString "table" "type" err

        Ok mtype ->
            case mtype of
                "chat" ->
                    case
                        decodeString
                            (field "payload"
                                (list
                                    (map2 Tuple.pair
                                        (field "user"
                                            (Dec.nullable
                                                chatterDecoder
                                            )
                                        )
                                        (field "message" Dec.string)
                                    )
                                )
                            )
                            message
                    of
                        Ok chat ->
                            Ok (TableMsg table <| Chat <| chat)

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "enter" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Enter <| Just user

                        Err _ ->
                            Ok <| TableMsg table <| Enter Nothing

                "exit" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok user ->
                            Ok <| TableMsg table <| Exit <| Just user

                        Err _ ->
                            Ok <| TableMsg table <| Exit Nothing

                "update" ->
                    case decodeString (field "payload" tableDecoder) message of
                        Ok update ->
                            Ok <| TableMsg table <| Update update

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "roll" ->
                    case decodeString (field "payload" rollDecoder) message of
                        Ok roll ->
                            Ok <| TableMsg table <| Roll roll

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "move" ->
                    case decodeString (field "payload" moveDecoder) message of
                        Ok move ->
                            Ok <| TableMsg table <| Move move

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "eliminations" ->
                    case decodeString (field "payload" eliminationsDecoder) message of
                        Ok ( eliminations, players ) ->
                            Ok <| TableMsg table <| Eliminations eliminations players

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "error" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok error ->
                            Ok <| TableMsg table <| Error error

                        Err _ ->
                            Ok <| TableMsg table <| Error <| "💣"

                "join" ->
                    case decodeString (field "payload" playersDecoder) message of
                        Ok player ->
                            Ok <| TableMsg table <| Join player

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "leave" ->
                    case decodeString (field "payload" playersDecoder) message of
                        Ok player ->
                            Ok <| TableMsg table <| Leave player

                        Err err ->
                            Err <| errorToString err

                "takeover" ->
                    case decodeString (field "payload" <| tupleDecoder playersDecoder playersDecoder) message of
                        Ok ( player, replaced ) ->
                            Ok <| TableMsg table <| Takeover player replaced

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                "turn" ->
                    case decodeString (field "payload" turnDecoder) message of
                        Ok info ->
                            Ok <| TableMsg table <| Turn info

                        Err err ->
                            Err <| errorToString err

                "player" ->
                    case decodeString (field "payload" playersDecoder) message of
                        Ok player ->
                            Ok <| TableMsg table <| PlayerStatus player

                        Err err ->
                            Err <| decodeErrorToString "table" mtype err

                _ ->
                    Err <| "unknown table message type \"" ++ mtype ++ "\""


decodeClientMessage : String -> Result String Msg
decodeClientMessage message =
    case decodeString (field "type" Dec.string) message of
        Err err ->
            Err <| errorToString err

        Ok mtype ->
            case mtype of
                "user" ->
                    case decodeString (field "payload" meDecoder) message of
                        Ok ( user, token, preferences ) ->
                            Ok <| UpdateUser user token preferences

                        Err err ->
                            Err <| decodeErrorToString "client" mtype err

                "error" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok error ->
                            Ok <|
                                if String.startsWith "JsonWebTokenError" error then
                                    ErrorToast "Login error, please log in again." error

                                else
                                    ErrorToast error error

                        Err err ->
                            Ok <| ErrorToast "💣 Server-client error" <| errorToString err

                "message" ->
                    case decodeString (field "payload" Dec.string) message of
                        Ok messageString ->
                            Ok <| MessageToast messageString <| Nothing

                        Err err ->
                            Ok <| ErrorToast "Error parsing message" <| errorToString err

                _ ->
                    Err <| "unknown client message type: " ++ mtype


encodeTopic : Topic -> String
encodeTopic topic =
    case topic of
        AllClients ->
            "clients"

        Client id ->
            "clients/" ++ id

        Tables table direction ->
            "tables/" ++ table ++ "/" ++ encodeDirection direction


encodeDirection : TopicDirection -> String
encodeDirection direction =
    case direction of
        ClientDirection ->
            "clients"

        ServerDirection ->
            "server"


decodeDirection : String -> Result String TopicDirection
decodeDirection string =
    case string of
        "clients" ->
            Ok ClientDirection

        "server" ->
            Ok ServerDirection

        _ ->
            Err <| "bad direction: " ++ string


decodeErrorToString : String -> String -> Error -> String
decodeErrorToString topic type_ err =
    "(" ++ topic ++ "/" ++ type_ ++ ") " ++ Dec.errorToString err
