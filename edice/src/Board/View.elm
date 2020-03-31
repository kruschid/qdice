module Board.View exposing (view)

import Animation
import Animation.Messenger
import Array
import Board.Colors
import Board.PathCache
import Board.Types exposing (..)
import Color
import Color.Accessibility
import Dict
import Helpers exposing (dataTestId, dataTestValue)
import Html
import Html.Attributes
import Html.Lazy
import Land exposing (Land, Layout, landCenter)
import String
import Svg exposing (..)
import Svg.Attributes exposing (..)
import Svg.Events exposing (..)
import Svg.Lazy


empty : List a
empty =
    []


view : Model -> Maybe Land.Emoji -> Bool -> Html.Html Msg
view model hovered diceVisible =
    Html.Lazy.lazy7 board
        model.map
        model.layout
        model.pathCache
        model.animations
        model.move
        hovered
        diceVisible


board : Land.Map -> ( Layout, String, String ) -> PathCache -> Animations -> BoardMove -> Maybe Land.Emoji -> Bool -> Svg Msg
board map ( layout, sWidth, sHeight ) pathCache animations move hovered diceVisible =
    Html.div [ class "edBoard" ]
        [ Svg.svg
            [ viewBox ("0 0 " ++ sWidth ++ " " ++ sHeight)
            , preserveAspectRatio "xMidYMin meet"
            , class "edBoard--svg"
            ]
            [ die
            , Svg.Lazy.lazy4 waterConnections layout pathCache map.extraAdjacency map.lands
            , Svg.Lazy.lazy5 realLands
                layout
                pathCache
                move
                hovered
                map.lands
            , Svg.Lazy.lazy4 allDies layout animations map.lands diceVisible
            ]
        ]


realLands :
    Layout
    -> PathCache
    -> BoardMove
    -> Maybe Land.Emoji
    -> List Land
    -> Svg Msg
realLands layout pathCache move hovered lands =
    g [] <|
        List.map
            (lazyLandElement layout
                pathCache
                move
                hovered
            )
            lands


lazyLandElement :
    Layout
    -> PathCache
    -> BoardMove
    -> Maybe Land.Emoji
    -> Land.Land
    -> Svg Msg
lazyLandElement layout pathCache move hovered land =
    let
        isSelected =
            case move of
                Idle ->
                    False

                From from ->
                    land == from

                FromTo from to ->
                    land == from || land == to

        isHovered =
            case hovered of
                Just emoji ->
                    emoji == land.emoji

                Nothing ->
                    False
    in
    Svg.Lazy.lazy5 landElement layout pathCache isSelected isHovered land


landElement : Layout -> PathCache -> Bool -> Bool -> Land.Land -> Svg Msg
landElement layout pathCache isSelected isHovered land =
    polygon
        [ fill <| landColor isSelected isHovered land.color
        , stroke "black"
        , strokeLinejoin "round"
        , strokeWidth "1"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        , points <| Board.PathCache.points pathCache layout land
        , class "edLand"
        , onClick (ClickLand land.emoji)
        , onMouseOver (HoverLand land.emoji)
        , onMouseOut (UnHoverLand land.emoji)
        , dataTestId <| "land-" ++ land.emoji
        , dataTestValue "selected"
            (if isSelected then
                "true"

             else
                "false"
            )
        ]
        []


allDies : Layout -> Animations -> List Land.Land -> Bool -> Svg Msg
allDies layout animations lands diceVisible =
    g [] <| List.map (lazyLandDies layout animations diceVisible) lands


lazyLandDies : Layout -> Animations -> Bool -> Land.Land -> Svg Msg
lazyLandDies layout animations diceVisible land =
    let
        stackAnimation : Maybe (Animation.Messenger.State Msg)
        stackAnimation =
            Dict.get ("attack_" ++ land.emoji) animations
                |> Maybe.andThen
                    (\a ->
                        case a of
                            Animation b ->
                                Just b

                            _ ->
                                Nothing
                    )

        diceAnimations : Array.Array Bool
        diceAnimations =
            getDiceAnimations animations land
    in
    Svg.Lazy.lazy5 landDies layout stackAnimation diceAnimations diceVisible land


getDiceAnimations : Animations -> Land.Land -> Array.Array Bool
getDiceAnimations dict land =
    let
        animations =
            List.range 0 (land.points - 1)
                |> List.map (getLandDieKey land)
                |> List.map (\k -> Dict.get k dict)
                |> List.map
                    (\v ->
                        case v of
                            Just a ->
                                case a of
                                    CssAnimation _ ->
                                        True

                                    _ ->
                                        False

                            Nothing ->
                                False
                    )
    in
    if
        List.any
            identity
            animations
    then
        Array.fromList animations

    else
        Array.empty


landDies : Layout -> Maybe (Animation.Messenger.State Msg) -> Array.Array Bool -> Bool -> Land.Land -> Svg Msg
landDies layout stackAnimation diceAnimations diceVisible land =
    let
        ( x_, y_ ) =
            landCenter
                layout
                land.cells

        animationAttrs =
            case stackAnimation of
                Just animation ->
                    Animation.render animation

                Nothing ->
                    []
    in
    if diceVisible == True then
        g
            (class "edBoard--stack"
                :: animationAttrs
            )
        <|
            List.map
                (Svg.Lazy.lazy4 landDie diceAnimations x_ y_)
            <|
                List.range
                    0
                    (land.points - 1)

    else
        let
            color =
                Color.Accessibility.maximumContrast (Board.Colors.base land.color)
                    [ Color.rgb255 30 30 30, Color.rgb255 225 225 225 ]
                    |> Maybe.withDefault (Color.rgb255 30 30 30)

            oppositeColor =
                Color.Accessibility.maximumContrast color
                    [ Color.rgb255 30 30 30, Color.rgb255 225 225 225 ]
                    |> Maybe.withDefault (Color.rgb255 255 255 255)
        in
        text_
            ([ class "edBoard--stack edBoard--stack__text"
             , x <| String.fromFloat x_
             , y <| String.fromFloat y_
             , oppositeColor
                |> Board.Colors.cssRgb
                |> stroke
             , color
                |> Board.Colors.cssRgb
                |> fill
             , textAnchor "middle"
             ]
                ++ animationAttrs
            )
            [ Svg.text <| String.fromInt land.points ]


landDie : Array.Array Bool -> Float -> Float -> Int -> Svg Msg
landDie animations cx cy index =
    let
        ( xOffset, yOffset ) =
            if index >= 4 then
                ( 1.0, 1.1 )

            else
                ( 2.2, 2 )

        animation : Bool
        animation =
            case Array.get index animations of
                Just b ->
                    b

                Nothing ->
                    False
    in
    Svg.use
        ((if animation == False then
            [ class "edBoard--dies" ]

          else
            [ class "edBoard--dies edBoard--dies__animated"
            , Svg.Attributes.style <| "animation-delay: " ++ (String.fromFloat <| (*) 0.1 <| toFloat index) ++ "s"
            ]
         )
            ++ [ y <| String.fromFloat <| cy - yOffset - (toFloat (modBy 4 index) * 1.2)
               , x <| String.fromFloat <| cx - xOffset
               , textAnchor "middle"
               , alignmentBaseline "central"
               , xlinkHref "#die"
               , height "3"
               , width "3"
               ]
        )
        []


waterConnections : Layout -> PathCache -> List ( Land.Emoji, Land.Emoji ) -> List Land -> Svg Msg
waterConnections layout pathCache connections lands =
    g [] <| List.map (waterConnection layout pathCache lands) connections


waterConnection : Layout -> PathCache -> List Land.Land -> ( Land.Emoji, Land.Emoji ) -> Svg Msg
waterConnection layout pathCache lands ( from, to ) =
    Svg.path
        [ d <| Board.PathCache.line pathCache layout lands from to
        , fill "none"
        , stroke "black"
        , strokeDasharray "3 2"
        , strokeLinejoin "round"
        , strokeWidth "2"
        , Html.Attributes.attribute "vector-effect" "non-scaling-stroke"
        ]
        []


landColor : Bool -> Bool -> Land.Color -> String
landColor selected hovered color =
    Board.Colors.base color
        |> (if selected then
                Board.Colors.highlight

            else
                identity
           )
        |> (if hovered then
                Board.Colors.hover

            else
                identity
           )
        |> Board.Colors.cssRgb


die : Svg Msg
die =
    defs []
        [ g
            [ id "die"
            , transform "scale(0.055)"
            ]
            [ Svg.path
                [ Svg.Attributes.style
                    "opacity:1;fill:none;fill-opacity:1;stroke:#000000;stroke-width:4;stroke-linecap:round;stroke-linejoin:miter;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , d "M 44.274701,38.931604 44.059081,18.315979 23.545011,3.0644163 3.0997027,18.315979 2.9528307,38.931604 23.613771,54.273792 Z"
                ]
                []
            , rect
                [ Svg.Attributes.style "opacity:1;fill:#ffffff;fill-opacity:1;stroke:#000000;stroke-width:0.70753205;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "rect4157"
                , width "25.320923"
                , height "25.320923"
                , x "-13.198412"
                , y "17.248964"
                , transform "matrix(0.8016383,-0.59780937,0.8016383,0.59780937,0,0)"
                ]
                []
            , Svg.path
                [ Svg.Attributes.style
                    "opacity:1;fill:#ebebeb;fill-opacity:1;stroke:#000000;stroke-width:0.57285416;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , d "m 2.9522657,18.430618 20.5011153,15.342466 0,20.501118 L 2.9522657,38.931736 Z"
                ]
                []
            , Svg.path
                [ Svg.Attributes.style
                    "opacity:1;fill:#ebebeb;fill-opacity:1;stroke:#000000;stroke-width:0.57285416;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , d "m 44.275301,18.430618 -20.50112,15.342466 0,20.501118 20.50112,-15.342466 z"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "path4165"
                , cx "23.545307"
                , cy "18.201725"
                , rx "4.7748194"
                , ry "3.5811143"
                ]
                []
            , ellipse
                [ cy "42.152149"
                , cx "-8.0335274"
                , id "circle4167"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , rx "2.1917808"
                , ry "2.53085"
                , transform "matrix(1,0,0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "circle4171"
                , cx "55.690258"
                , cy "42.094212"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "ellipse4173"
                , cx "-8.2909203"
                , cy "32.980541"
                ]
                []
            , ellipse
                [ cy "50.764507"
                , cx "-7.6902356"
                , id "ellipse4175"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,-0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , cy "31.414658"
                , cx "55.871754"
                , id "ellipse4177"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "ellipse4179"
                , cx "61.509121"
                , cy "43.270634"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                , id "ellipse4181"
                , cx "49.791553"
                , cy "41.145508"
                , rx "2.1917808"
                , ry "2.5308504"
                , transform "matrix(1,0,-0.5,0.8660254,0,0)"
                ]
                []
            , ellipse
                [ transform "matrix(1,0,-0.5,0.8660254,0,0)"
                , ry "2.5308504"
                , rx "2.1917808"
                , cy "51.882996"
                , cx "55.063419"
                , id "ellipse4183"
                , Svg.Attributes.style "opacity:1;fill:#000000;fill-opacity:1;stroke:none;stroke-width:0.80000001;stroke-linejoin:round;stroke-miterlimit:4;stroke-dasharray:none;stroke-opacity:1"
                ]
                []
            ]
        ]
