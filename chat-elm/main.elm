import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode exposing (..)
import Json.Encode
import Maybe exposing(withDefault)
import WebSocket



main =
  Html.program
    { init = init
    , view = view
    , update = update
    , subscriptions = subscriptions
    }


echoServer : String
echoServer =
  "ws://localhost:5000/"



-- MODEL


type alias Model =
  { name : String
  , input : String
  , states : List State
  , onlineCount : Int
  }

type alias State =
  { name : String
  , message: String
  }

init : (Model, Cmd Msg)
init =
  (Model "" "" [] 0, Cmd.none)

-- UPDATE

stateToJson : State -> String
stateToJson state = Json.Encode.encode 0
                      <| Json.Encode.object
                           [ ("name", Json.Encode.string state.name)
                           , ("message", Json.Encode.string state.message)
                           ]
jsonToState : String -> Maybe State
jsonToState str = let
                    nameRes = decodeString (field "name" string) str
                    messageRes = decodeString (field "message" string) str
                  in
                    case (nameRes, messageRes) of
                      (Ok name, Ok message) -> Just { name = name, message = message }
                      _                     -> Nothing

jsonToOnlineCount : String -> Maybe Int
jsonToOnlineCount str = case decodeString (field "online_count" int) str of
                          Ok online -> Just online
                          _         -> Nothing

-- State -> OnlineCount -> Passの順に評価を試みる
jsonToMsg : String -> Msg
jsonToMsg str = withDefault (withDefault Pass <| Maybe.map NewOnlineCount <| jsonToOnlineCount str) <| Maybe.map NewState <| jsonToState str

type Msg
  = ChangeName String
  | Input String
  | Send
  | NewState State
  | NewOnlineCount Int
  | Pass

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    ChangeName newName ->
      ({ model | name = newName }, Cmd.none)

    Input newInput ->
      ({ model | input = newInput}, Cmd.none)

    Send ->
      ({ model | input = "" }, WebSocket.send echoServer ( stateToJson <| { name = model.name, message = model.input }))

    NewState state ->
      ({ model | states = state :: model.states }, Cmd.none)

    NewOnlineCount online ->
      ({ model | onlineCount = online }, Cmd.none)

    Pass ->
      (model, Cmd.none)


-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
  WebSocket.listen echoServer jsonToMsg



-- VIEW


view : Model -> Html Msg
view model =
  div []
      [ div [ class "row" ]
            [ div [ class "col s12" ] (List.map viewState (List.reverse model.states)) ],
        div [ class "row"]
            [ div [ class "input-field col s3" ]
                  [ input [ type_ "text", onInput ChangeName, id "name" ] [],
                    label [ for "name" ] [ text "Name" ]
                  ],
              div [ class "input-field col s6" ]
                  [ input [ type_ "text", onInput Input, onEnter Send, Html.Attributes.value model.input, id "message" ] [],
                    label [ for "message" ] [ text "Message" ]
                  ],
              button [ class "waves-effect waves-light btn", onClick Send ] [text "Send"]
            ]
      ]

viewState : State -> Html msg
viewState state =
  div [ class "card-panel" ]
      [ div [ class "card-content" ]
            [ span [ class "card-title" ] [ text state.name ],
              p [] [ text state.message ]
            ]
      ]

onEnter : Msg -> Attribute Msg
onEnter msg = on "keyup" (Json.Decode.map (\c -> if c == 13 then Send else Pass ) keyCode)

