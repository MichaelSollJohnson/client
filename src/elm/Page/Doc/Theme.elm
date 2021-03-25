module Page.Doc.Theme exposing (Theme(..), applyTheme, decoder, setTourStep, toValue)

import Html
import Html.Attributes exposing (class)
import Json.Decode as Dec exposing (Decoder)
import Json.Encode as Enc


type Theme
    = Default
    | Gray
    | Green
    | Turquoise
    | Dark


applyTheme : Theme -> Html.Attribute msg
applyTheme theme =
    case theme of
        Default ->
            class ""

        Gray ->
            class "gray-theme"

        Green ->
            class "green-theme"

        Turquoise ->
            class "turquoise-theme"

        Dark ->
            class "dark-theme"


setTourStep : Maybe Int -> Html.Attribute msg
setTourStep step_ =
    case step_ of
        Nothing ->
            class ""

        Just step ->
            class ("step-" ++ String.fromInt step)


toValue : Theme -> Enc.Value
toValue theme =
    case theme of
        Default ->
            Enc.string "default"

        Gray ->
            Enc.string "gray"

        Green ->
            Enc.string "green"

        Turquoise ->
            Enc.string "turquoise"

        Dark ->
            Enc.string "dark"


decoder : Decoder Theme
decoder =
    Dec.field "theme" Dec.string
        |> Dec.map
            (\s ->
                case s of
                    "default" ->
                        Default

                    "gray" ->
                        Gray

                    "green" ->
                        Green

                    "turquoise" ->
                        Turquoise

                    "dark" ->
                        Dark

                    _ ->
                        Default
            )
