module Doc.UI exposing (countWords, viewConflict, viewFooter, viewHeader, viewHistory, viewHomeLink, viewSaveIndicator, viewSearchField, viewSidebar, viewSidebarStatic, viewVideo)

import Coders exposing (treeToMarkdownString)
import Diff exposing (..)
import Doc.Data as Data
import Doc.Data.Conflict as Conflict exposing (Conflict, Op(..), Selection(..), opString)
import Doc.List as DocList
import Doc.Metadata exposing (Metadata)
import Doc.TreeStructure as TreeStructure exposing (defaultTree)
import Doc.TreeUtils exposing (..)
import Html exposing (Html, a, button, del, div, fieldset, h1, hr, iframe, img, input, ins, label, li, span, text, ul)
import Html.Attributes as A exposing (..)
import Html.Events exposing (onClick, onInput)
import List.Extra as ListExtra exposing (getAt)
import Octicons as Icon exposing (defaultOptions)
import Regex exposing (Regex, replace)
import Route
import Time exposing (posixToMillis)
import Translation exposing (Language, TranslationId(..), timeDistInWords, tr)
import Types exposing (Children(..), CursorPosition(..), TextCursorInfo, ViewMode(..), ViewState)
import User exposing (User)



-- HEADER


viewHomeLink : Bool -> Html msg
viewHomeLink sidebarOpen =
    div [ id "home" ]
        [ a [ id "home-link", href (Route.toString Route.Home) ]
            [ img [ src "../gingko-leaf-logo.svg", width 28 ]
                []
            , if sidebarOpen then
                span [ id "home-link-name" ] [ text "Home" ]

              else
                text ""
            ]
        ]


type alias HeaderMsgs msg =
    { toggledTitleEdit : Bool -> msg
    , titleFieldChanged : String -> msg
    , titleEdited : msg
    , toggledAccountMenu : Bool -> msg
    }


viewHeader : HeaderMsgs msg -> Maybe String -> { m | titleField : Maybe String, accountMenuOpen : Bool, dirty : Bool, lastLocalSave : Maybe Time.Posix, lastRemoteSave : Maybe Time.Posix, currentTime : Time.Posix, user : User } -> Html msg
viewHeader msgs title_ model =
    let
        language =
            User.language model.user
    in
    case model.titleField of
        Just editingField ->
            div [ id "document-header" ]
                [ span [ id "title" ]
                    [ input [ onInput msgs.titleFieldChanged, value editingField ] []
                    , button [ onClick msgs.titleEdited ] [ text "Rename" ]
                    ]
                , viewAccount msgs.toggledAccountMenu model.accountMenuOpen model.user
                ]

        Nothing ->
            div [ id "document-header" ]
                [ span [ id "title" ]
                    [ h1 [ onClick (msgs.toggledTitleEdit True) ]
                        [ text (title_ |> Maybe.withDefault "Untitled")
                        ]
                    , viewSaveIndicator language model
                    ]
                , viewAccount msgs.toggledAccountMenu model.accountMenuOpen model.user
                ]


viewSaveIndicator :
    Language
    -> { m | dirty : Bool, lastLocalSave : Maybe Time.Posix, lastRemoteSave : Maybe Time.Posix, currentTime : Time.Posix }
    -> Html msg
viewSaveIndicator language { dirty, lastLocalSave, lastRemoteSave, currentTime } =
    let
        lastChangeString =
            timeDistInWords
                language
                (lastLocalSave |> Maybe.withDefault (Time.millisToPosix 0))
                currentTime

        saveStateSpan =
            if dirty then
                span [ title (tr language LastSaved ++ " " ++ lastChangeString) ] [ text <| tr language UnsavedChanges ]

            else
                case ( lastLocalSave, lastRemoteSave ) of
                    ( Nothing, Nothing ) ->
                        span [] [ text <| tr language NeverSaved ]

                    ( Just _, Nothing ) ->
                        span [ title (tr language LastEdit ++ " " ++ lastChangeString) ] [ text <| tr language SavedInternally ]

                    ( Just commitTime, Just fileTime ) ->
                        if posixToMillis commitTime <= posixToMillis fileTime then
                            span [ title (tr language LastEdit ++ " " ++ lastChangeString) ]
                                [ text <| tr language ChangesSynced ]

                        else
                            span [ title (tr language LastEdit ++ " " ++ lastChangeString) ] [ text <| tr language SavedInternally ]

                    ( Nothing, Just _ ) ->
                        span [ title (tr language LastEdit ++ " " ++ lastChangeString) ] [ text <| tr language DatabaseError ]
    in
    div
        [ id "save-indicator", classList [ ( "inset", True ), ( "saving", dirty ) ] ]
        [ saveStateSpan
        ]


viewAccount : (Bool -> msg) -> Bool -> User -> Html msg
viewAccount toggleMsg isOpen user =
    let
        userIcon =
            Icon.person (defaultOptions |> Icon.color "#333" |> Icon.size 18)
    in
    div [ id "account", onClick (toggleMsg (not isOpen)) ]
        [ userIcon
        , if isOpen then
            div [ id "account-dropdown" ]
                [ text (User.name user |> Maybe.withDefault "")
                , hr [] []
                , a [ href (Route.toString Route.Logout) ] [ text "Logout" ]
                ]

          else
            text ""
        ]



-- SIDEBAR


type alias SidebarMsgs msg =
    { toggledSidebar : Bool -> msg
    , exportAll : msg
    }


viewSidebar : SidebarMsgs msg -> Metadata -> DocList.Model -> Bool -> List (Html msg)
viewSidebar msgs currentDocument docList isOpen =
    let
        sidebarMenu =
            if isOpen then
                div [ id "sidebar-menu" ]
                    [ a [ href (Route.toString Route.DocNew), class "sidebar-item" ] [ text "New" ]
                    , hr [ style "width" "80%" ] []
                    , DocList.viewSmall currentDocument docList
                    , hr [ style "width" "80%" ] []
                    , button [ onClick msgs.exportAll, class "sidebar-item" ] [ text "Export to docx" ]
                    ]

            else
                text ""

        fileIconColor =
            if isOpen then
                "hsl(202 22% 44%)"

            else
                "hsl(202 22% 66%)"

        fileIcon =
            Icon.fileDirectory (defaultOptions |> Icon.color fileIconColor |> Icon.size 18)
    in
    [ div [ id "sidebar", classList [ ( "open", isOpen ) ] ]
        [ div [ classList [ ( "sidebar-button", True ), ( "open", isOpen ) ], onClick <| msgs.toggledSidebar (not isOpen) ] [ fileIcon ] ]
    , sidebarMenu
    ]


viewSidebarStatic : Html msg
viewSidebarStatic =
    div [ id "sidebar" ]
        [ div [ classList [ ( "sidebar-button", True ) ] ] []
        ]



-- DOCUMENT


viewSearchField : (String -> msg) -> { m | viewState : ViewState, user : User } -> Html msg
viewSearchField searchFieldMsg { viewState, user } =
    let
        language =
            User.language user

        maybeSearchIcon =
            if viewState.searchField == Nothing then
                Icon.search (defaultOptions |> Icon.color "#445" |> Icon.size 12)

            else
                text ""
    in
    case viewState.viewMode of
        Normal ->
            div
                [ id "search-field" ]
                [ input
                    [ type_ "search"
                    , id "search-input"
                    , required True
                    , title (tr language PressToSearch)
                    , onInput searchFieldMsg
                    ]
                    []
                , maybeSearchIcon
                ]

        _ ->
            div
                [ id "search-field" ]
                []


viewFooter : msg -> msg -> { m | viewState : ViewState, workingTree : TreeStructure.Model, startingWordcount : Int, shortcutTrayOpen : Bool, wordcountTrayOpen : Bool, user : User, isMac : Bool, textCursorInfo : TextCursorInfo } -> Html msg
viewFooter wordCountToggle shortcutToggle model =
    let
        language =
            User.language model.user

        wordCounts =
            getWordCounts model

        current =
            wordCounts.document

        session =
            current - model.startingWordcount

        viewWordCount =
            case model.viewState.viewMode of
                Normal ->
                    [ div
                        [ id "wordcount"
                        , classList [ ( "inset", True ), ( "open", model.wordcountTrayOpen ) ]
                        , onClick wordCountToggle
                        ]
                        [ span [] [ text (tr language (WordCountSession session)) ]
                        , span [] [ text (tr language (WordCountTotal current)) ]
                        , span [] [ text (tr language (WordCountCard wordCounts.card)) ]
                        , span [] [ text (tr language (WordCountSubtree wordCounts.subtree)) ]
                        , span [] [ text (tr language (WordCountGroup wordCounts.group)) ]
                        , span [] [ text (tr language (WordCountColumn wordCounts.column)) ]
                        ]
                    ]

                _ ->
                    []

        isOnly =
            case model.workingTree.tree.children of
                Children [ singleRoot ] ->
                    if singleRoot.children == Children [] then
                        True

                    else
                        False

                _ ->
                    False
    in
    div
        [ class "footer" ]
        ([ viewShortcutsToggle shortcutToggle language model.shortcutTrayOpen model.isMac isOnly model.textCursorInfo model.viewState ]
            ++ viewWordCount
        )


viewHistory : msg -> (String -> msg) -> msg -> msg -> Translation.Language -> String -> Data.Model -> Html msg
viewHistory noopMsg checkoutMsg restoreMsg cancelMsg lang currHead dataModel =
    let
        master =
            Data.head "heads/master" dataModel

        historyList =
            case master of
                Just refObj ->
                    (refObj.value :: refObj.ancestors)
                        |> List.reverse

                _ ->
                    []

        maxIdx =
            historyList |> List.length |> (\x -> x - 1) |> String.fromInt

        currIdx =
            historyList
                |> ListExtra.elemIndex currHead
                |> Maybe.map String.fromInt
                |> Maybe.withDefault maxIdx

        checkoutCommit idxStr =
            case String.toInt idxStr of
                Just idx ->
                    case getAt idx historyList of
                        Just commit ->
                            checkoutMsg commit

                        Nothing ->
                            noopMsg

                Nothing ->
                    noopMsg
    in
    div [ id "history" ]
        [ input [ type_ "range", A.min "0", A.max maxIdx, value currIdx, step "1", onInput checkoutCommit ] []
        , button [ onClick restoreMsg ] [ text <| tr lang RestoreThisVersion ]
        , button [ onClick cancelMsg ] [ text <| tr lang Cancel ]
        ]


viewVideo : (Bool -> msg) -> { m | videoModalOpen : Bool } -> Html msg
viewVideo modalMsg { videoModalOpen } =
    if videoModalOpen then
        div [ class "modal-container" ]
            [ div [ class "modal" ]
                [ div [ class "modal-header" ]
                    [ h1 [] [ text "Learning Videos" ]
                    , a [ onClick (modalMsg False) ] [ text "×" ]
                    ]
                , iframe
                    [ width 650
                    , height 366
                    , src "https://www.youtube.com/embed/ZOGgwKAU3vg?rel=0&amp;showinfo=0"
                    , attribute "frameborder" "0"
                    , attribute "allowfullscreen" ""
                    ]
                    []
                ]
            ]

    else
        div [] []


viewShortcutsToggle : msg -> Language -> Bool -> Bool -> Bool -> TextCursorInfo -> ViewState -> Html msg
viewShortcutsToggle trayToggleMsg lang isOpen isMac isOnly textCursorInfo vs =
    let
        isTextSelected =
            textCursorInfo.selected

        viewIf cond content =
            if cond then
                content

            else
                text ""

        spanSplit key descAdd descSplit =
            if textCursorInfo.position == End || textCursorInfo.position == Empty then
                shortcutSpan [ ctrlOrCmd, key ] descAdd

            else
                shortcutSpan [ ctrlOrCmd, key ] descSplit

        splitChild =
            spanSplit "L" (tr lang AddChildAction) (tr lang SplitChildAction)

        splitBelow =
            spanSplit "J" (tr lang AddBelowAction) (tr lang SplitBelowAction)

        splitAbove =
            spanSplit "K" (tr lang AddAboveAction) (tr lang SplitUpwardAction)

        shortcutSpanEnabled enabled keys desc =
            let
                keySpans =
                    keys
                        |> List.map (\k -> span [ class "shortcut-key" ] [ text k ])
            in
            span
                [ classList [ ( "disabled", not enabled ) ] ]
                (keySpans
                    ++ [ text (" " ++ desc) ]
                )

        shortcutSpan =
            shortcutSpanEnabled True

        ctrlOrCmd =
            if isMac then
                "⌘"

            else
                "Ctrl"
    in
    if isOpen then
        let
            iconColor =
                Icon.color "#445"
        in
        case vs.viewMode of
            Normal ->
                div
                    [ id "shortcuts-tray", class "inset", onClick trayToggleMsg ]
                    [ div [ class "popup" ]
                        [ shortcutSpan [ tr lang EnterKey ] (tr lang EnterAction)
                        , viewIf (not isOnly) <| shortcutSpan [ "↑", "↓", "←", "→" ] (tr lang ArrowsAction)
                        , shortcutSpan [ ctrlOrCmd, "→" ] (tr lang AddChildAction)
                        , shortcutSpan [ ctrlOrCmd, "↓" ] (tr lang AddBelowAction)
                        , shortcutSpan [ ctrlOrCmd, "↑" ] (tr lang AddAboveAction)
                        , viewIf (not isOnly) <| shortcutSpan [ "Alt", tr lang ArrowKeys ] (tr lang MoveAction)
                        , viewIf (not isOnly) <| shortcutSpan [ ctrlOrCmd, tr lang Backspace ] (tr lang DeleteAction)
                        , shortcutSpan [ ctrlOrCmd, "Shift", "↓" ] (tr lang MergeDownAction)
                        , shortcutSpan [ ctrlOrCmd, "Shift", "↑" ] (tr lang MergeUpAction)
                        ]
                    , div [ class "icon-stack" ]
                        [ Icon.keyboard (defaultOptions |> iconColor)
                        , Icon.question (defaultOptions |> iconColor |> Icon.size 14)
                        ]
                    ]

            _ ->
                div
                    [ id "shortcuts-tray", class "inset", onClick trayToggleMsg ]
                    [ div [ class "popup" ]
                        [ shortcutSpan [ ctrlOrCmd, tr lang EnterKey ] (tr lang ToSaveChanges)
                        , shortcutSpan [ tr lang EscKey ] (tr lang ToCancelChanges)
                        , splitChild
                        , splitBelow
                        , splitAbove
                        , shortcutSpanEnabled isTextSelected [ ctrlOrCmd, "B" ] (tr lang ForBold)
                        , shortcutSpanEnabled isTextSelected [ ctrlOrCmd, "I" ] (tr lang ForItalic)
                        , span [ class "markdown-guide" ]
                            [ a [ href "http://commonmark.org/help" ]
                                [ text <| tr lang FormattingGuide
                                , span [ class "icon-container" ] [ Icon.linkExternal (defaultOptions |> iconColor |> Icon.size 14) ]
                                ]
                            ]
                        ]
                    , div [ class "icon-stack" ]
                        [ Icon.keyboard (defaultOptions |> iconColor)
                        , Icon.question (defaultOptions |> iconColor |> Icon.size 14)
                        ]
                    ]

    else
        let
            iconColor =
                Icon.color "#6c7c84"
        in
        div
            [ id "shortcuts-tray", class "inset", onClick trayToggleMsg, title <| tr lang KeyboardHelp ]
            [ div [ class "icon-stack" ]
                [ Icon.keyboard (defaultOptions |> iconColor)
                , Icon.question (defaultOptions |> iconColor |> Icon.size 14)
                ]
            ]



-- Word count


type alias WordCount =
    { card : Int
    , subtree : Int
    , group : Int
    , column : Int
    , document : Int
    }


viewWordcountProgress : Int -> Int -> Html msg
viewWordcountProgress current session =
    let
        currW =
            1 / (1 + toFloat session / toFloat current)

        sessW =
            1 - currW
    in
    div [ id "wc-progress" ]
        [ div [ id "wc-progress-wrap" ]
            [ span [ style "flex" (String.fromFloat currW), id "wc-progress-bar" ] []
            , span [ style "flex" (String.fromFloat sessW), id "wc-progress-bar-session" ] []
            ]
        ]


getWordCounts : { m | viewState : ViewState, workingTree : TreeStructure.Model } -> WordCount
getWordCounts model =
    let
        activeCardId =
            model.viewState.active

        tree =
            model.workingTree.tree

        currentTree =
            getTree activeCardId tree
                |> Maybe.withDefault defaultTree

        currentGroup =
            getSiblings activeCardId tree

        cardCount =
            countWords currentTree.content

        subtreeCount =
            cardCount + countWords (treeToMarkdownString False currentTree)

        groupCount =
            currentGroup
                |> List.map .content
                |> String.join "\n\n"
                |> countWords

        columnCount =
            getColumn (getDepth 0 tree activeCardId) tree
                -- Maybe (List (List Tree))
                |> Maybe.withDefault [ [] ]
                |> List.concat
                |> List.map .content
                |> String.join "\n\n"
                |> countWords

        treeCount =
            countWords (treeToMarkdownString False tree)
    in
    WordCount
        cardCount
        subtreeCount
        groupCount
        columnCount
        treeCount


countWords : String -> Int
countWords str =
    let
        punctuation =
            Regex.fromString "[!@#$%^&*():;\"',.]+"
                |> Maybe.withDefault Regex.never
    in
    str
        |> String.toLower
        |> replace punctuation (\_ -> "")
        |> String.words
        |> List.filter ((/=) "")
        |> List.length


viewConflict : (String -> Selection -> String -> msg) -> (String -> msg) -> Conflict -> Html msg
viewConflict setSelectionMsg resolveMsg { id, opA, opB, selection, resolved } =
    let
        withManual cardId oursElement theirsElement =
            li
                []
                [ fieldset []
                    [ radio (setSelectionMsg id Original cardId) (selection == Original) (text "Original")
                    , radio (setSelectionMsg id Ours cardId) (selection == Ours) oursElement
                    , radio (setSelectionMsg id Theirs cardId) (selection == Theirs) theirsElement
                    , radio (setSelectionMsg id Manual cardId) (selection == Manual) (text "Merged")
                    , label []
                        [ input [ checked resolved, type_ "checkbox", onClick (resolveMsg id) ] []
                        , text "Resolved"
                        ]
                    ]
                ]

        withoutManual cardIdA cardIdB =
            li
                []
                [ fieldset []
                    [ radio (setSelectionMsg id Original "") (selection == Original) (text "Original")
                    , radio (setSelectionMsg id Ours cardIdA) (selection == Ours) (text ("Ours:" ++ (opString opA |> String.left 3)))
                    , radio (setSelectionMsg id Theirs cardIdB) (selection == Theirs) (text ("Theirs:" ++ (opString opB |> String.left 3)))
                    , label []
                        [ input [ checked resolved, type_ "checkbox", onClick (resolveMsg id) ] []
                        , text "Resolved"
                        ]
                    ]
                ]

        newConflictView cardId ourChanges theirChanges =
            div [ class "flex-row" ]
                [ div [ class "conflict-container flex-column" ]
                    [ div
                        [ classList [ ( "row option", True ), ( "selected", selection == Original ) ]
                        , onClick (setSelectionMsg id Original cardId)
                        ]
                        [ text "Original" ]
                    , div [ class "row flex-row" ]
                        [ div
                            [ classList [ ( "option", True ), ( "selected", selection == Ours ) ]
                            , onClick (setSelectionMsg id Ours cardId)
                            ]
                            [ text "Ours"
                            , ul [ class "changelist" ] ourChanges
                            ]
                        , div
                            [ classList [ ( "option", True ), ( "selected", selection == Theirs ) ]
                            , onClick (setSelectionMsg id Theirs cardId)
                            ]
                            [ text "Theirs"
                            , ul [ class "changelist" ] theirChanges
                            ]
                        ]
                    , div
                        [ classList [ ( "row option", True ), ( "selected", selection == Manual ) ]
                        , onClick (setSelectionMsg id Manual cardId)
                        ]
                        [ text "Merged" ]
                    ]
                , button [ onClick (resolveMsg id) ] [ text "Resolved" ]
                ]
    in
    case ( opA, opB ) of
        ( Mod idA _ _ _, Mod _ _ _ _ ) ->
            let
                diffLinesString l r =
                    diffLines l r
                        |> List.filterMap
                            (\c ->
                                case c of
                                    NoChange s ->
                                        Nothing

                                    Added s ->
                                        Just (li [] [ ins [ class "diff" ] [ text s ] ])

                                    Removed s ->
                                        Just (li [] [ del [ class "diff" ] [ text s ] ])
                            )
            in
            newConflictView idA [] []

        ( Conflict.Ins idA _ _ _, Del idB _ ) ->
            withoutManual idA idB

        ( Del idA _, Conflict.Ins idB _ _ _ ) ->
            withoutManual idA idB

        _ ->
            withoutManual "" ""


radio : msg -> Bool -> Html msg -> Html msg
radio msg bool labelElement =
    label []
        [ input [ type_ "radio", checked bool, onClick msg ] []
        , labelElement
        ]
