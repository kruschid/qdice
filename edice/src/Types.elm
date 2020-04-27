module Types exposing (..)

import Animation
import Array exposing (Array)
import Backend.Types
import Board
import Browser
import Browser.Navigation exposing (Key)
import Dict exposing (Dict)
import Game.Types exposing (Award, PlayerAction, TableInfo)
import Games.Replayer.Types exposing (ReplayerCmd, ReplayerModel)
import Games.Types exposing (Game, GameRef)
import Http exposing (Error)
import MyProfile.Types
import OAuth
import Placeholder exposing (Placeheld)
import Tables exposing (Table)
import Time
import Url exposing (Url)


type Msg
    = NavigateTo Route
    | OnLocationChange Url
    | OnUrlRequest Browser.UrlRequest
    | Tick Time.Posix
    | Resized Int Int
    | UserZone Time.Zone
    | Animate Animation.Msg
    | MyProfileMsg MyProfile.Types.MyProfileMsg
    | ErrorToast String String
    | MessageToast String (Maybe Int)
    | RequestFullscreen
    | RequestNotifications
    | RenounceNotifications
    | SetSessionPreference SessionPreference
    | NotificationsChange ( String, Maybe PushSubscription, Maybe String ) -- 3rd item is JWT, because this might come right after logout
    | NotificationClick String
    | PushGetKey
    | PushKey (Result Error String)
    | PushRegister PushSubscription
    | PushRegisterEvent ( PushEvent, Bool )
    | LeaderboardMsg LeaderboardMsg
    | GamesMsg GamesMsg
    | RuntimeError String String
      -- oauth
    | Nop
    | GetGlobalSettings (Result Error GlobalQdice)
    | Authorize AuthState
    | GetToken (Maybe Table) (Result Error String)
    | GetUpdateProfile (Result String String)
    | GetProfile (Result Error ( LoggedUser, String, Preferences ))
    | GetOtherProfile (Result Error OtherProfile)
    | Logout
    | ShowLogin LoginDialogStatus
    | Register String (Maybe Table)
    | SetLoginName String
    | SetLoginPassword LoginPasswordStep
    | SetPassword ( String, String ) (Maybe String) -- (email, pass) check
    | UpdateUser LoggedUser String Preferences
    | GetComments CommentKind (Result String (List Comment))
    | InputComment CommentKind String
    | PostComment CommentKind (Maybe CommentKind) String
    | GetPostComment CommentKind (Maybe CommentKind) (Result String Comment)
    | ReplyComment CommentKind (Maybe ( Int, String ))
      -- game
    | BoardMsg Board.Msg
    | InputChat String
    | SendChat String
    | GameCmd PlayerAction
    | GameMsg Game.Types.Msg
    | EnterGame Table
    | ExpandChats
      -- replayer
    | ReplayerCmd ReplayerCmd
      -- backend
    | Connected Backend.Types.ClientId
    | StatusConnect String
    | StatusReconnect Int
    | StatusOffline String
    | StatusError String
    | Subscribed Backend.Types.Topic
    | ClientMsg Backend.Types.ClientMessage
    | AllClientsMsg Backend.Types.AllClientsMessage
    | TableMsg Table Backend.Types.TableMessage
    | UnknownTopicMessage String String String String
    | SetLastHeartbeat Time.Posix


type alias AuthState =
    { network : AuthNetwork
    , table : Maybe Table
    , addTo : Maybe UserId
    }


type LoginPasswordStep
    = StepEmail String
    | StepPassword String
    | StepNext Int (Maybe Table)


type StaticPage
    = Help
    | About


type Route
    = HomeRoute
    | GameRoute Table
    | StaticPageRoute StaticPage
    | NotFoundRoute
    | MyProfileRoute
    | TokenRoute String
    | ProfileRoute UserId String
    | LeaderBoardRoute
    | GamesRoute GamesSubRoute


type GamesSubRoute
    = AllGames
    | GamesOfTable Table
    | GameId Table Int


type alias Model =
    { route : Route
    , key : Key
    , oauth : MyOAuthModel
    , game : Game.Types.Model
    , myProfile : MyProfile.Types.MyProfileModel
    , backend : Backend.Types.Model
    , user : User
    , tableList : List TableInfo
    , time : Time.Posix
    , zone : Time.Zone
    , isTelegram : Bool
    , zip : Bool
    , screenshot : Bool
    , loginName : String
    , loginPassword :
        { step : Int
        , email : String
        , password : String
        , animations : ( Animation.State, Animation.State )
        }
    , showLoginDialog : LoginDialogStatus
    , settings : GlobalSettings
    , leaderBoard : LeaderBoardModel
    , otherProfile : Placeheld OtherProfile
    , preferences : Preferences
    , sessionPreferences : SessionPreferences
    , games :
        { tables : Dict String (List Game)
        , all : List Game
        , fetching : Maybe GamesSubRoute
        }
    , fullscreen : Bool
    , comments : CommentsModel
    , replayer : Maybe ReplayerModel
    }


type alias Flags =
    { version : String
    , token : Maybe String
    , isTelegram : Bool
    , screenshot : Bool
    , notificationsEnabled : Bool
    , muted : Bool
    , zip : Bool
    }


type User
    = Anonymous
    | Logged LoggedUser


type alias LoggedUser =
    { id : UserId
    , name : Username
    , email : Maybe String
    , picture : String
    , points : Int
    , rank : Int
    , level : Int
    , levelPoints : Int
    , claimed : Bool
    , networks : List AuthNetwork
    , voted : List String
    , awards : List Award
    }


type alias UserPreferences =
    {}


type AuthNetwork
    = Password
    | Google
    | Reddit
    | Telegram


type alias MyOAuthModel =
    { redirectUri : Url
    , error : Maybe String
    , token : Maybe OAuth.Token
    , state : String
    }


getUsername : Model -> String
getUsername model =
    case model.user of
        Anonymous ->
            "Anonymous"

        Logged user ->
            user.name


type alias UserId =
    String


type alias Username =
    String


type alias GlobalQdice =
    { settings : GlobalSettings
    , tables : List TableInfo
    , leaderBoard : ( String, List Profile )
    , version : String
    }


type alias GlobalSettings =
    { gameCountdownSeconds : Int
    , maxNameLength : Int
    , turnSeconds : Int
    }


type LoginDialogStatus
    = LoginShow
    | LoginShowJoin
    | LoginHide


type alias Profile =
    { id : UserId
    , name : Username
    , rank : Int
    , picture : String
    , points : Int
    , level : Int
    , levelPoints : Int
    , awards : List Award
    , registered : Bool
    }


type alias OtherProfile =
    ( Profile, ProfileStats )


type alias ProfileStats =
    { games : List GameRef
    , gamesWon : Int
    , gamesPlayed : Int
    , stats : ProfileStatsStatistics
    }


type alias ProfileStatsStatistics =
    { rolls : Array Int
    , attacks : ( Int, Int )
    }


type alias LeaderBoardModel =
    { loading : Bool
    , month : String
    , top : List Profile
    , board : List Profile
    , page : Int
    }


type alias LeaderBoardResponse =
    { month : String
    , board : List Profile
    , page : Int
    }


type alias Preferences =
    { pushEvents : List PushEvent
    }


type alias SessionPreferences =
    { notificationsEnabled : Bool
    , muted : Bool
    }


type SessionPreference
    = Muted Bool


type alias PushSubscription =
    String


type PushEvent
    = GameStart
    | PlayerJoin


type LeaderboardMsg
    = GetLeaderboard (Result Error LeaderBoardResponse)
    | GotoPage Int


type GamesMsg
    = GetGames GamesSubRoute (Result Error (List Game))


type CommentKind
    = UserWall String String
    | GameComments Int String
    | TableComments String
    | ReplyComments Int String
    | StaticPageComments StaticPage


commentKindKey : CommentKind -> String
commentKindKey kind =
    case kind of
        UserWall id _ ->
            "user/" ++ id

        GameComments id _ ->
            "games/" ++ String.fromInt id

        TableComments table ->
            "tables/" ++ table

        ReplyComments id _ ->
            "comments/" ++ String.fromInt id

        StaticPageComments page ->
            "page/"
                ++ (case page of
                        Help ->
                            "help"

                        About ->
                            "about"
                   )


type alias Comment =
    { id : Int
    , kind : CommentKind
    , author : CommentAuthor
    , timestamp : Int
    , text : String
    , replies : Replies
    }


type Replies
    = Replies (List Comment)


type alias CommentAuthor =
    { id : Int
    , name : String
    , picture : String
    }


type CommentList
    = CommentListFetching
    | CommentListError String
    | CommentListFetched (List Comment)


type alias CommentModel =
    { list : CommentList
    , postState :
        { value : String
        , status : CommentPostStatus
        , kind : Maybe CommentKind
        }
    }


type CommentPostStatus
    = CommentPostIdle
    | CommentPosting
    | CommentPostError String
    | CommentPostSuccess


type alias CommentsModel =
    Dict String CommentModel
