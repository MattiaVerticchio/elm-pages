module GenerateMain exposing (..)

import Elm exposing (File)
import Elm.Annotation as Type
import Elm.Case
import Elm.Declare
import Elm.Extra exposing (expose, fnIgnore, topLevelValue)
import Elm.Let
import Elm.Op
import Elm.Pattern
import Gen.ApiRoute
import Gen.Basics
import Gen.Bytes
import Gen.Bytes.Decode
import Gen.Bytes.Encode
import Gen.DataSource
import Gen.Dict
import Gen.Head
import Gen.HtmlPrinter
import Gen.Json.Decode
import Gen.Json.Encode
import Gen.List
import Gen.Maybe
import Gen.Pages.Internal.NotFoundReason
import Gen.Pages.Internal.Platform
import Gen.Pages.Internal.RoutePattern
import Gen.Pages.ProgramConfig
import Gen.Pages.Transition
import Gen.Path
import Gen.Platform.Sub
import Gen.Server.Response
import Gen.Tuple
import Gen.Url
import Pages.Internal.RoutePattern as RoutePattern exposing (RoutePattern)


type Phase
    = Browser
    | Cli


otherFile : List RoutePattern.RoutePattern -> String -> File
otherFile routes phaseString =
    let
        phase : Phase
        phase =
            case phaseString of
                "browser" ->
                    Browser

                _ ->
                    Cli

        config :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        config =
            { init = Elm.apply (Elm.val "init") [ Elm.nothing ]
            , update = update.value []
            , subscriptions = subscriptions.value []
            , sharedData =
                Elm.value { name = "template", importFrom = [ "Shared" ], annotation = Nothing }
                    |> Elm.get "data"
            , data = dataForRoute.value []
            , action = action.value []
            , onActionData = onActionData.value []
            , view = todo
            , handleRoute = handleRoute.value []
            , getStaticRoutes =
                case phase of
                    Browser ->
                        Gen.DataSource.succeed (Elm.list [])

                    Cli ->
                        getStaticRoutes.reference
                            |> Gen.DataSource.map (Gen.List.call_.map (Elm.val "Just"))
            , urlToRoute =
                Elm.value
                    { annotation = Nothing
                    , name = "urlToRoute"
                    , importFrom = [ "Route" ]
                    }
            , routeToPath =
                Elm.fn ( "route", Nothing )
                    (\route ->
                        route
                            |> Gen.Maybe.map
                                (\value ->
                                    Elm.apply
                                        (Elm.value
                                            { annotation = Nothing
                                            , name = "routeToPath"
                                            , importFrom = [ "Route" ]
                                            }
                                        )
                                        [ value ]
                                )
                            |> Gen.Maybe.withDefault (Elm.list [])
                    )
            , site =
                case phase of
                    Browser ->
                        Elm.nothing

                    Cli ->
                        Elm.just
                            (Elm.value
                                { name = "config"
                                , annotation = Nothing
                                , importFrom = [ "Site" ]
                                }
                            )
            , toJsPort = Elm.val "toJsPort"
            , fromJsPort = applyIdentityTo (Elm.val "fromJsPort")
            , gotBatchSub =
                case phase of
                    Browser ->
                        Gen.Platform.Sub.none

                    Cli ->
                        applyIdentityTo (Elm.val "gotBatchSub")
            , hotReloadData =
                applyIdentityTo (Elm.val "hotReloadData")
            , onPageChange = Elm.val "OnPageChange"
            , apiRoutes =
                Elm.fn ( "htmlToString", Nothing )
                    (\htmlToString ->
                        case phase of
                            Browser ->
                                Elm.list []

                            Cli ->
                                Elm.Op.cons pathsToGenerateHandler.reference
                                    (Elm.Op.cons routePatterns.reference
                                        (Elm.Op.cons apiPatterns.reference
                                            (Elm.apply (Elm.value { name = "routes", importFrom = [ "Api" ], annotation = Nothing })
                                                [ getStaticRoutes.reference
                                                , htmlToString
                                                ]
                                            )
                                        )
                                    )
                    )
            , pathPatterns = pathPatterns.reference
            , basePath =
                Elm.value
                    { name = "baseUrlAsPath"
                    , importFrom = [ "Route" ]
                    , annotation = Nothing
                    }
            , sendPageData = Elm.val "sendPageData"
            , byteEncodePageData = byteEncodePageData.value []
            , byteDecodePageData = byteDecodePageData.value []
            , encodeResponse = encodeResponse.reference
            , encodeAction = encodeActionData.value []
            , decodeResponse = decodeResponse.reference
            , globalHeadTags =
                case phase of
                    Browser ->
                        Elm.nothing

                    Cli ->
                        Elm.just globalHeadTags.reference
            , cmdToEffect =
                Elm.value
                    { annotation = Nothing
                    , name = "fromCmd"
                    , importFrom = [ "Effect" ]
                    }
            , perform =
                Elm.value
                    { annotation = Nothing
                    , name = "perform"
                    , importFrom = [ "Effect" ]
                    }
            , errorStatusCode =
                Elm.value
                    { annotation = Nothing
                    , name = "statusCode"
                    , importFrom = [ "ErrorPage" ]
                    }
            , notFoundPage =
                Elm.value
                    { annotation = Nothing
                    , name = "notFound"
                    , importFrom = [ "ErrorPage" ]
                    }
            , internalError =
                Elm.value
                    { annotation = Nothing
                    , name = "internalError"
                    , importFrom = [ "ErrorPage" ]
                    }
            , errorPageToData = Elm.val "DataErrorPage____"
            , notFoundRoute = Elm.nothing
            }
                |> Gen.Pages.ProgramConfig.make_.programConfig
                |> Elm.withType
                    (Gen.Pages.ProgramConfig.annotation_.programConfig
                        (Type.named [] "Msg")
                        (Type.named [] "Model")
                        (Type.maybe (Type.named [ "Route" ] "Route"))
                        (Type.named [] "PageData")
                        (Type.named [] "ActionData")
                        (Type.named [ "Shared" ] "Data")
                        (Type.namedWith [ "Effect" ] "Effect" [ Type.named [] "Msg" ])
                        (Type.var "mappedMsg")
                        (Type.named [ "ErrorPage" ] "ErrorPage")
                    )
                |> topLevelValue "config"

        pathPatterns :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        pathPatterns =
            topLevelValue "routePatterns3"
                (routes
                    |> List.map routePatternToSyntax
                    |> Elm.list
                )

        subscriptions :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        subscriptions =
            Elm.Declare.fn3 "subscriptions"
                ( "route", Nothing )
                ( "path", Nothing )
                ( "model", Nothing )
                (\route path model ->
                    Gen.Platform.Sub.batch
                        [ Elm.apply
                            (Elm.value
                                { importFrom = [ "Shared" ]
                                , name = "template"
                                , annotation = Nothing
                                }
                                |> Elm.get "subscriptions"
                            )
                            [ path
                            , model
                                |> Elm.get "global"
                            ]
                            |> Gen.Platform.Sub.call_.map (Elm.val "MsgGlobal")
                        , templateSubscriptions.call route path model
                        ]
                )

        onActionData :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        onActionData =
            Elm.Declare.fn "onActionData"
                ( "actionData", Type.named [] "ActionData" |> Just )
                (\actionData ->
                    Elm.Case.custom actionData
                        Type.unit
                        (routes
                            |> List.map
                                (\route ->
                                    Elm.Case.branch1
                                        ("ActionData" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                        ( "thisActionData", Type.unit )
                                        (\thisActionData ->
                                            (Elm.value
                                                { annotation = Nothing
                                                , importFrom = "Route" :: RoutePattern.toModuleName route
                                                , name = "route"
                                                }
                                                |> Elm.get "onAction"
                                            )
                                                |> Gen.Maybe.map
                                                    (\onAction ->
                                                        Elm.apply
                                                            (Elm.val
                                                                ("Msg" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                                            )
                                                            [ Elm.apply onAction [ thisActionData ] ]
                                                    )
                                        )
                                )
                        )
                        |> Elm.withType (Type.maybe (Type.named [] "Msg"))
                )

        templateSubscriptions :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        templateSubscriptions =
            Elm.Declare.fn3 "templateSubscriptions"
                ( "route", Type.maybe (Type.named [ "Route" ] "Route") |> Just )
                ( "path", Type.named [ "Path" ] "Path" |> Just )
                ( "model", Type.named [] "Model" |> Just )
                (\maybeRoute path model ->
                    Elm.Case.maybe maybeRoute
                        { nothing =
                            Gen.Platform.Sub.none
                        , just =
                            ( "justRoute"
                            , \justRoute ->
                                branchHelper justRoute
                                    (\route maybeRouteParams ->
                                        Elm.Case.custom (model |> Elm.get "page")
                                            Type.unit
                                            [ Elm.Case.branch1
                                                ("Model" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                                ( "templateModel", Type.unit )
                                                (\templateModel ->
                                                    Elm.apply
                                                        (Elm.value
                                                            { importFrom = "Route" :: RoutePattern.toModuleName route
                                                            , name = "route"
                                                            , annotation = Nothing
                                                            }
                                                            |> Elm.get "subscriptions"
                                                        )
                                                        [ Elm.nothing -- TODO wire through value
                                                        , maybeRouteParams |> Maybe.withDefault (Elm.record [])
                                                        , path
                                                        , templateModel
                                                        , model |> Elm.get "global"
                                                        ]
                                                        |> Gen.Platform.Sub.call_.map
                                                            (Elm.val
                                                                ("Msg" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                                            )
                                                )
                                            , Elm.Case.otherwise (\_ -> Gen.Platform.Sub.none)
                                            ]
                                    )
                            )
                        }
                )

        dataForRoute :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        dataForRoute =
            Elm.Declare.fn
                "dataForRoute"
                ( "maybeRoute", Type.maybe (Type.named [ "Route" ] "Route") |> Just )
                (\maybeRoute ->
                    Elm.Case.maybe maybeRoute
                        { nothing =
                            Gen.DataSource.succeed
                                (Gen.Server.Response.mapError Gen.Basics.never
                                    (Gen.Server.Response.withStatusCode 404
                                        (Gen.Server.Response.render (Elm.val "Data404NotFoundPage____"))
                                    )
                                )
                        , just =
                            ( "justRoute"
                            , \justRoute ->
                                branchHelper justRoute
                                    (\route maybeRouteParams ->
                                        Elm.apply
                                            (Elm.value
                                                { name = "route"
                                                , importFrom = "Route" :: (route |> RoutePattern.toModuleName)
                                                , annotation = Nothing
                                                }
                                                |> Elm.get "data"
                                            )
                                            [ maybeRouteParams
                                                |> Maybe.withDefault (Elm.record [])
                                            ]
                                            |> Gen.DataSource.map
                                                (Gen.Server.Response.call_.map (Elm.val ("Data" ++ (RoutePattern.toModuleName route |> String.join "__"))))
                                    )
                            )
                        }
                        |> Elm.withType
                            (Gen.DataSource.annotation_.dataSource
                                (Gen.Server.Response.annotation_.response
                                    (Type.named [] "PageData")
                                    (Type.named [ "ErrorPage" ] "ErrorPage")
                                )
                            )
                )

        action :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        action =
            Elm.Declare.fn
                "action"
                ( "maybeRoute", Type.maybe (Type.named [ "Route" ] "Route") |> Just )
                (\maybeRoute ->
                    Elm.Case.maybe maybeRoute
                        { nothing =
                            Gen.DataSource.succeed
                                (Gen.Server.Response.plainText "TODO")
                        , just =
                            ( "justRoute"
                            , \justRoute ->
                                branchHelper justRoute
                                    (\route maybeRouteParams ->
                                        Elm.apply
                                            (Elm.value
                                                { name = "route"
                                                , importFrom = "Route" :: (route |> RoutePattern.toModuleName)
                                                , annotation = Nothing
                                                }
                                                |> Elm.get "action"
                                            )
                                            [ maybeRouteParams
                                                |> Maybe.withDefault (Elm.record [])
                                            ]
                                            |> Gen.DataSource.map
                                                (Gen.Server.Response.call_.map (Elm.val ("ActionData" ++ (RoutePattern.toModuleName route |> String.join "__"))))
                                    )
                            )
                        }
                        |> Elm.withType
                            (Gen.DataSource.annotation_.dataSource
                                (Gen.Server.Response.annotation_.response
                                    (Type.named [] "ActionData")
                                    (Type.named [ "ErrorPage" ] "ErrorPage")
                                )
                            )
                )

        init :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        init =
            Elm.Declare.fn6 "init"
                ( "currentGlobalModel", Type.maybe (Type.named [ "Shared" ] "Model") |> Just )
                ( "userFlags", Type.named [ "Pages", "Flags" ] "Flags" |> Just )
                ( "sharedData", Type.named [ "Shared" ] "Data" |> Just )
                ( "pageData", Type.named [] "PageData" |> Just )
                ( "actionData", Type.named [] "ActionData" |> Type.maybe |> Just )
                ( "maybePagePath"
                , Type.record
                    [ ( "path"
                      , Type.record
                            [ ( "path", Type.named [ "Path" ] "Path" )
                            , ( "query", Type.string |> Type.maybe )
                            , ( "fragment", Type.string |> Type.maybe )
                            ]
                      )
                    , ( "metadata", Type.maybe (Type.named [ "Route" ] "Route") )
                    , ( "pageUrl", Type.maybe (Type.named [ "Pages", "PageUrl" ] "PageUrl") )
                    ]
                    |> Type.maybe
                    |> Just
                )
                (\currentGlobalModel userFlags sharedData pageData actionData maybePagePath ->
                    Elm.Let.letIn
                        (\( sharedModel, globalCmd ) ->
                            Elm.Let.letIn
                                (\( templateModel, templateCmd ) ->
                                    Elm.tuple
                                        (Elm.record
                                            [ ( "global", sharedModel )
                                            , ( "page", templateModel )
                                            , ( "current", maybePagePath )
                                            ]
                                        )
                                        (Elm.apply
                                            (Elm.value
                                                { annotation = Nothing
                                                , name = "batch"
                                                , importFrom = [ "Effect" ]
                                                }
                                            )
                                            [ Elm.list
                                                [ templateCmd
                                                , Elm.apply
                                                    (Elm.value
                                                        { annotation = Nothing
                                                        , importFrom = [ "Effect" ]
                                                        , name = "map"
                                                        }
                                                    )
                                                    [ Elm.val "MsgGlobal"
                                                    , globalCmd
                                                    ]
                                                ]
                                            ]
                                        )
                                )
                                |> Elm.Let.tuple "templateModel"
                                    "templateCmd"
                                    (Elm.Case.maybe
                                        (Gen.Maybe.map2 Gen.Tuple.pair
                                            (maybePagePath |> Gen.Maybe.andThen (Elm.get "metadata"))
                                            (maybePagePath |> Gen.Maybe.map (Elm.get "path"))
                                        )
                                        { nothing = initErrorPage.call pageData
                                        , just =
                                            ( "justRouteAndPath"
                                            , \justRouteAndPath ->
                                                branchHelper (Gen.Tuple.first justRouteAndPath)
                                                    (\route routeParams ->
                                                        Elm.Case.custom pageData
                                                            Type.unit
                                                            [ Elm.Case.branch1
                                                                ("Data" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                                                ( "thisPageData", Type.unit )
                                                                (\thisPageData ->
                                                                    Elm.apply
                                                                        (Elm.value
                                                                            { name = "route"
                                                                            , importFrom = "Route" :: RoutePattern.toModuleName route
                                                                            , annotation = Nothing
                                                                            }
                                                                            |> Elm.get "init"
                                                                        )
                                                                        [ Gen.Maybe.andThen (Elm.get "pageUrl") maybePagePath
                                                                        , sharedModel
                                                                        , Elm.record
                                                                            [ ( "data", thisPageData )
                                                                            , ( "sharedData", sharedData )
                                                                            , ( "action"
                                                                              , actionData
                                                                                    |> Gen.Maybe.andThen
                                                                                        (\justActionData ->
                                                                                            Elm.Case.custom justActionData
                                                                                                Type.unit
                                                                                                [ Elm.Case.branch1
                                                                                                    ("ActionData" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                                                                                    ( "thisActionData", Type.unit )
                                                                                                    (\_ ->
                                                                                                        Elm.just (Elm.val "thisActionData")
                                                                                                    )
                                                                                                , Elm.Case.otherwise (\_ -> Elm.nothing)
                                                                                                ]
                                                                                        )
                                                                              )
                                                                            , ( "routeParams", routeParams |> Maybe.withDefault (Elm.record []) )
                                                                            , ( "path"
                                                                              , Elm.apply (Elm.val ".path") [ justRouteAndPath |> Gen.Tuple.second ]
                                                                              )
                                                                            , ( "submit"
                                                                              , Elm.apply
                                                                                    (Elm.value
                                                                                        { importFrom = [ "Pages", "Fetcher" ]
                                                                                        , name = "submit"
                                                                                        , annotation = Nothing
                                                                                        }
                                                                                    )
                                                                                    [ Elm.value
                                                                                        { importFrom = "Route" :: RoutePattern.toModuleName route
                                                                                        , name = "w3_decode_ActionData"
                                                                                        , annotation = Nothing
                                                                                        }
                                                                                    ]
                                                                              )
                                                                            , ( "transition", Elm.nothing )
                                                                            , ( "fetchers", Gen.Dict.empty )
                                                                            , ( "pageFormState", Gen.Dict.empty )
                                                                            ]
                                                                        ]
                                                                        |> Gen.Tuple.call_.mapBoth
                                                                            (Elm.val ("Model" ++ (RoutePattern.toModuleName route |> String.join "__")))
                                                                            (Elm.apply
                                                                                (Elm.value { name = "map", importFrom = [ "Effect" ], annotation = Nothing })
                                                                                [ Elm.val ("Msg" ++ (RoutePattern.toModuleName route |> String.join "__")) ]
                                                                            )
                                                                )
                                                            , Elm.Case.otherwise
                                                                (\_ ->
                                                                    initErrorPage.call pageData
                                                                )
                                                            ]
                                                    )
                                            )
                                        }
                                    )
                                |> Elm.Let.toExpression
                        )
                        |> Elm.Let.tuple "sharedModel"
                            "globalCmd"
                            (currentGlobalModel
                                |> Gen.Maybe.map
                                    (\m ->
                                        Elm.tuple m (Elm.value { annotation = Nothing, importFrom = [ "Effect" ], name = "none" })
                                    )
                                |> Gen.Maybe.withDefault
                                    (Elm.apply
                                        (Elm.value
                                            { importFrom = [ "Shared" ]
                                            , name = "template"
                                            , annotation = Nothing
                                            }
                                            |> Elm.get "init"
                                        )
                                        [ userFlags, maybePagePath ]
                                    )
                            )
                        |> Elm.Let.toExpression
                        |> Elm.withType
                            (Type.tuple
                                (Type.named [] "Model")
                                (Type.namedWith [ "Effect" ] "Effect" [ Type.named [] "Msg" ])
                            )
                )

        update :
            { declaration : Elm.Declaration
            , call : List Elm.Expression -> Elm.Expression
            , callFrom : List String -> List Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        update =
            Elm.Declare.function "update"
                [ ( "pageFormState", Type.named [ "Pages", "FormState" ] "PageFormState" |> Just )
                , ( "fetchers"
                  , Gen.Dict.annotation_.dict
                        Type.string
                        (Gen.Pages.Transition.annotation_.fetcherState (Type.named [] "ActionData"))
                        |> Just
                  )
                , ( "transition", Type.named [ "Pages", "Transition" ] "Transition" |> Type.maybe |> Just )
                , ( "sharedData", Type.named [ "Shared" ] "Data" |> Just )
                , ( "pageData", Type.named [] "PageData" |> Just )
                , ( "navigationKey", Type.named [ "Browser", "Navigation" ] "Key" |> Type.maybe |> Just )
                , ( "msg", Type.named [] "Msg" |> Just )
                , ( "model", Type.named [] "Model" |> Just )
                ]
                (\args ->
                    case args of
                        [ pageFormState, fetchers, transition, sharedData, pageData, navigationKey, msg, model ] ->
                            Elm.Case.custom msg
                                Type.unit
                                ([ Elm.Pattern.variant1 "MsgErrorPage____" (Elm.Pattern.var "msg_")
                                    |> Elm.Case.patternToBranch
                                        (\msg_ ->
                                            Elm.Let.letIn
                                                (\( updatedPageModel, pageCmd ) ->
                                                    Elm.tuple
                                                        (Elm.updateRecord
                                                            [ ( "page", updatedPageModel )
                                                            ]
                                                            model
                                                        )
                                                        pageCmd
                                                )
                                                |> Elm.Let.destructure (Elm.Pattern.tuple (Elm.Pattern.var "updatedPageModel") (Elm.Pattern.var "pageCmd"))
                                                    (Elm.Case.custom (Elm.tuple (model |> Elm.get "page") pageData)
                                                        Type.unit
                                                        [ Elm.Pattern.tuple (Elm.Pattern.variant1 "ModelErrorPage____" (Elm.Pattern.var "pageModel"))
                                                            (Elm.Pattern.variant1 "DataErrorPage____" (Elm.Pattern.var "thisPageData"))
                                                            |> Elm.Case.patternToBranch
                                                                (\( pageModel, thisPageData ) ->
                                                                    Elm.apply
                                                                        (Elm.value
                                                                            { importFrom = [ "ErrorPage" ]
                                                                            , name = "update"
                                                                            , annotation = Nothing
                                                                            }
                                                                        )
                                                                        [ thisPageData
                                                                        , msg_
                                                                        , pageModel
                                                                        ]
                                                                        |> Gen.Tuple.call_.mapBoth (Elm.val "ModelErrorPage____")
                                                                            (Elm.apply
                                                                                (Elm.value
                                                                                    { name = "map"
                                                                                    , importFrom = [ "Effect" ]
                                                                                    , annotation = Nothing
                                                                                    }
                                                                                )
                                                                                [ Elm.val "MsgErrorPage____" ]
                                                                            )
                                                                )
                                                        , Elm.Pattern.ignore
                                                            |> Elm.Case.patternToBranch
                                                                (\() ->
                                                                    Elm.tuple (model |> Elm.get "page") effectNone
                                                                )
                                                        ]
                                                    )
                                                |> Elm.Let.toExpression
                                        )
                                 , Elm.Pattern.variant1 "MsgGlobal" (Elm.Pattern.var "msg_")
                                    |> Elm.Case.patternToBranch
                                        (\msg_ ->
                                            todo
                                        )
                                 , Elm.Pattern.variant1 "OnPageChange" (Elm.Pattern.var "record")
                                    |> Elm.Case.patternToBranch
                                        (\record ->
                                            todo
                                        )
                                 ]
                                    ++ (routes
                                            |> List.map
                                                (\route ->
                                                    Elm.Pattern.variant1
                                                        ("Msg"
                                                            ++ (RoutePattern.toModuleName route |> String.join "__")
                                                        )
                                                        (Elm.Pattern.var "msg_")
                                                        |> Elm.Case.patternToBranch
                                                            (\msg_ ->
                                                                Elm.Case.custom
                                                                    (Elm.triple
                                                                        (model |> Elm.get "page")
                                                                        pageData
                                                                        (Gen.Maybe.call_.map3
                                                                            (toTriple.value [])
                                                                            (model
                                                                                |> Elm.get "current"
                                                                                |> Gen.Maybe.andThen
                                                                                    (Elm.get "metadata")
                                                                            )
                                                                            (model
                                                                                |> Elm.get "current"
                                                                                |> Gen.Maybe.andThen
                                                                                    (Elm.get "pageUrl")
                                                                            )
                                                                            (model
                                                                                |> Elm.get "current"
                                                                                |> Gen.Maybe.map
                                                                                    (Elm.get "path")
                                                                            )
                                                                        )
                                                                    )
                                                                    Type.unit
                                                                    [ Elm.Pattern.triple
                                                                        (Elm.Pattern.variant1
                                                                            ("Model"
                                                                                ++ (RoutePattern.toModuleName route |> String.join "__")
                                                                            )
                                                                            (Elm.Pattern.var "pageModel")
                                                                        )
                                                                        (Elm.Pattern.variant1
                                                                            ("Data"
                                                                                ++ (RoutePattern.toModuleName route |> String.join "__")
                                                                            )
                                                                            (Elm.Pattern.var "thisPageData")
                                                                        )
                                                                        (Elm.Pattern.variant1
                                                                            "Just"
                                                                            (Elm.Pattern.triple
                                                                                (routeToSyntaxPattern route)
                                                                                (Elm.Pattern.var "pageUrl")
                                                                                (Elm.Pattern.var "justPage")
                                                                            )
                                                                        )
                                                                        |> Elm.Case.patternToBranch
                                                                            (\( pageModel, thisPageData, ( maybeRouteParams, pageUrl, justPage ) ) ->
                                                                                Elm.Let.letIn
                                                                                    (\( updatedPageModel, pageCmd, ( newGlobalModel, newGlobalCmd ) ) ->
                                                                                        Elm.tuple
                                                                                            (model
                                                                                                |> Elm.updateRecord
                                                                                                    [ ( "page", updatedPageModel )
                                                                                                    , ( "global", newGlobalModel )
                                                                                                    ]
                                                                                            )
                                                                                            (Elm.apply
                                                                                                (Elm.value
                                                                                                    { name = "batch"
                                                                                                    , importFrom = [ "Effect" ]
                                                                                                    , annotation = Nothing
                                                                                                    }
                                                                                                )
                                                                                                [ Elm.list
                                                                                                    [ pageCmd
                                                                                                    , Elm.apply
                                                                                                        (Elm.value
                                                                                                            { name = "map"
                                                                                                            , importFrom = [ "Effect" ]
                                                                                                            , annotation = Nothing
                                                                                                            }
                                                                                                        )
                                                                                                        [ Elm.val "MsgGlobal"
                                                                                                        , newGlobalCmd
                                                                                                        ]
                                                                                                    ]
                                                                                                ]
                                                                                            )
                                                                                    )
                                                                                    |> Elm.Let.destructure
                                                                                        (Elm.Pattern.triple
                                                                                            (Elm.Pattern.var "updatedPageModel")
                                                                                            (Elm.Pattern.var "pageCmd")
                                                                                            (Elm.Pattern.tuple (Elm.Pattern.var "newGlobalModel")
                                                                                                (Elm.Pattern.var "newGlobalCmd")
                                                                                            )
                                                                                        )
                                                                                        (fooFn.call
                                                                                            --todo
                                                                                            (Elm.val ("Model" ++ (RoutePattern.toModuleName route |> String.join "__")))
                                                                                            (Elm.val ("Msg" ++ (RoutePattern.toModuleName route |> String.join "__")))
                                                                                            model
                                                                                            (Elm.apply
                                                                                                (Elm.value
                                                                                                    { annotation = Nothing
                                                                                                    , importFrom = "Route" :: RoutePattern.toModuleName route
                                                                                                    , name = "route"
                                                                                                    }
                                                                                                    |> Elm.get "update"
                                                                                                )
                                                                                                [ pageUrl
                                                                                                , Elm.record
                                                                                                    [ ( "data", thisPageData )
                                                                                                    , ( "sharedData", sharedData )
                                                                                                    , ( "action", Elm.nothing )
                                                                                                    , ( "routeParams", maybeRouteParams |> Maybe.withDefault (Elm.record []) )
                                                                                                    , ( "path", justPage |> Elm.get "path" )
                                                                                                    , ( "submit", todo )
                                                                                                    , ( "transition", transition )
                                                                                                    , ( "fetchers", todo )
                                                                                                    , ( "pageFormState", pageFormState )
                                                                                                    ]
                                                                                                , msg_
                                                                                                , pageModel
                                                                                                , model |> Elm.get "global"
                                                                                                ]
                                                                                            )
                                                                                        )
                                                                                    |> Elm.Let.toExpression
                                                                            )
                                                                    , Elm.Pattern.ignore
                                                                        |> Elm.Case.patternToBranch
                                                                            (\() ->
                                                                                Elm.tuple model effectNone
                                                                            )
                                                                    ]
                                                            )
                                                )
                                       )
                                )
                                |> Elm.withType
                                    (Type.tuple
                                        (Type.named [] "Model")
                                        (Type.namedWith [ "Effect" ] "Effect" [ Type.named [] "Msg" ])
                                    )

                        _ ->
                            todo
                )

        fooFn :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        fooFn =
            {-
               fooFn :
                   (a -> PageModel)
                   -> (b -> Msg)
                   -> Model
                   -> ( a, Effect.Effect b, Maybe Shared.Msg )
                   -> ( PageModel, Effect.Effect Msg, ( Shared.Model, Effect.Effect Msg ) )
               fooFn wrapModel wrapMsg model triple =
                   Debug.todo ""

            -}
            Elm.Declare.fn4 "fooFn"
                ( "wrapModel", Nothing )
                ( "wrapMsg", Nothing )
                ( "model", Type.named [] "Model" |> Just )
                ( "triple", Nothing )
                (\wrapModel wrapMsg model triple ->
                    Elm.Case.custom triple
                        Type.unit
                        [ Elm.Pattern.triple
                            (Elm.Pattern.var "a")
                            (Elm.Pattern.var "b")
                            (Elm.Pattern.var "c")
                            |> Elm.Case.patternToBranch
                                (\( a, b, c ) ->
                                    Elm.triple
                                        (Elm.apply wrapModel [ a ])
                                        (Elm.apply
                                            (Elm.value { name = "map", importFrom = [ "Effect" ], annotation = Nothing })
                                            [ wrapMsg, b ]
                                        )
                                        (Elm.Case.maybe c
                                            { nothing =
                                                Elm.tuple
                                                    (model |> Elm.get "global")
                                                    effectNone
                                            , just =
                                                ( "sharedMsg"
                                                , \sharedMsg ->
                                                    Elm.apply
                                                        (Elm.value
                                                            { importFrom = [ "Shared" ]
                                                            , name = "template"
                                                            , annotation = Nothing
                                                            }
                                                            |> Elm.get "update"
                                                        )
                                                        [ sharedMsg
                                                        , model |> Elm.get "global"
                                                        ]
                                                )
                                            }
                                        )
                                )
                        ]
                )

        toTriple :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        toTriple =
            Elm.Declare.fn3 "toTriple"
                ( "a", Nothing )
                ( "b", Nothing )
                ( "c", Nothing )
                (\a b c -> Elm.triple a b c)

        initErrorPage :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        initErrorPage =
            Elm.Declare.fn "initErrorPage"
                ( "pageData", Type.named [] "PageData" |> Just )
                (\pageData ->
                    Elm.apply
                        (Elm.value
                            { importFrom = [ "ErrorPage" ]
                            , name = "init"
                            , annotation = Nothing
                            }
                        )
                        [ Elm.Case.custom pageData
                            Type.unit
                            [ Elm.Case.branch1 "DataErrorPage____"
                                ( "errorPage", Type.unit )
                                (\errorPage -> errorPage)
                            , Elm.Case.otherwise (\_ -> Elm.value { importFrom = [ "ErrorPage" ], name = "notFound", annotation = Nothing })
                            ]
                        ]
                        |> Gen.Tuple.call_.mapBoth (Elm.val "ModelErrorPage____") (Elm.apply (Elm.value { name = "map", importFrom = [ "Effect" ], annotation = Nothing }) [ Elm.val "MsgErrorPage____" ])
                        |> Elm.withType (Type.tuple (Type.named [] "PageModel") (Type.namedWith [ "Effect" ] "Effect" [ Type.named [] "Msg" ]))
                )

        handleRoute :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        handleRoute =
            Elm.Declare.fn "handleRoute"
                ( "maybeRoute", Type.maybe (Type.named [ "Route" ] "Route") |> Just )
                (\maybeRoute ->
                    Elm.Case.maybe maybeRoute
                        { nothing = Gen.DataSource.succeed Elm.nothing
                        , just =
                            ( "route"
                            , \justRoute ->
                                branchHelper justRoute
                                    (\route innerRecord ->
                                        Elm.apply
                                            (Elm.value
                                                { annotation = Nothing
                                                , importFrom = "Route" :: RoutePattern.toModuleName route
                                                , name = "route"
                                                }
                                                |> Elm.get "handleRoute"
                                            )
                                            [ Elm.record
                                                [ ( "moduleName"
                                                  , RoutePattern.toModuleName route
                                                        |> List.map Elm.string
                                                        |> Elm.list
                                                  )
                                                , ( "routePattern"
                                                  , routePatternToSyntax route
                                                  )
                                                ]
                                            , Elm.fn ( "param", Nothing )
                                                (\param ->
                                                    -- TODO not implemented
                                                    todo
                                                )
                                            , innerRecord |> Maybe.withDefault (Elm.record [])
                                            ]
                                    )
                            )
                        }
                        |> Elm.withType
                            (Gen.DataSource.annotation_.dataSource (Type.maybe Gen.Pages.Internal.NotFoundReason.annotation_.notFoundReason))
                )

        branchHelper : Elm.Expression -> (RoutePattern -> Maybe Elm.Expression -> Elm.Expression) -> Elm.Expression
        branchHelper routeExpression toInnerExpression =
            Elm.Case.custom routeExpression
                Type.unit
                (routes
                    |> List.map
                        (\route ->
                            let
                                moduleName : String
                                moduleName =
                                    "Route." ++ (RoutePattern.toModuleName route |> String.join "__")
                            in
                            if RoutePattern.hasRouteParams route then
                                Elm.Case.branch1 moduleName
                                    ( "routeParams", Type.unit )
                                    (\routeParams ->
                                        toInnerExpression route (Just routeParams)
                                    )

                            else
                                Elm.Case.branch0 moduleName
                                    (toInnerExpression route Nothing)
                        )
                )

        encodeActionData :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        encodeActionData =
            Elm.Declare.fn "encodeActionData"
                ( "actionData", Type.named [] "ActionData" |> Just )
                (\actionData ->
                    Elm.Case.custom actionData
                        Type.unit
                        (routes
                            |> List.map
                                (\route ->
                                    Elm.Case.branch1
                                        ("ActionData" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                        ( "thisActionData", Type.unit )
                                        (\thisActionData ->
                                            Elm.apply
                                                (Elm.value
                                                    { annotation = Nothing
                                                    , importFrom = "Route" :: RoutePattern.toModuleName route
                                                    , name = "w3_encode_ActionData"
                                                    }
                                                )
                                                [ thisActionData ]
                                        )
                                )
                        )
                        |> Elm.withType Gen.Bytes.Encode.annotation_.encoder
                )

        byteEncodePageData :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        byteEncodePageData =
            Elm.Declare.fn "byteEncodePageData"
                ( "pageData", Type.named [] "PageData" |> Just )
                (\actionData ->
                    Elm.Case.custom actionData
                        Type.unit
                        ([ Elm.Case.branch1
                            "DataErrorPage____"
                            ( "thisPageData", Type.unit )
                            (\thisPageData ->
                                Elm.apply
                                    (Elm.value
                                        { annotation = Nothing
                                        , importFrom = [ "ErrorPage" ]
                                        , name = "w3_encode_Data"
                                        }
                                    )
                                    [ thisPageData ]
                            )
                         , Elm.Case.branch0 "Data404NotFoundPage____" (Gen.Bytes.Encode.unsignedInt8 0)
                         ]
                            ++ (routes
                                    |> List.map
                                        (\route ->
                                            Elm.Case.branch1
                                                ("Data" ++ (RoutePattern.toModuleName route |> String.join "__"))
                                                ( "thisPageData", Type.unit )
                                                (\thisPageData ->
                                                    Elm.apply
                                                        (Elm.value
                                                            { annotation = Nothing
                                                            , importFrom = "Route" :: RoutePattern.toModuleName route
                                                            , name = "w3_encode_Data"
                                                            }
                                                        )
                                                        [ thisPageData ]
                                                )
                                        )
                               )
                        )
                        |> Elm.withType Gen.Bytes.Encode.annotation_.encoder
                )

        byteDecodePageData :
            { declaration : Elm.Declaration
            , call : Elm.Expression -> Elm.Expression
            , callFrom : List String -> Elm.Expression -> Elm.Expression
            , value : List String -> Elm.Expression
            }
        byteDecodePageData =
            Elm.Declare.fn "byteDecodePageData"
                ( "route", Type.named [ "Route" ] "Route" |> Type.maybe |> Just )
                (\maybeRoute ->
                    Elm.Case.maybe maybeRoute
                        { nothing = Gen.Bytes.Decode.values_.fail
                        , just =
                            ( "route"
                            , \route_ ->
                                Elm.Case.custom route_
                                    Type.unit
                                    (routes
                                        |> List.map
                                            (\route ->
                                                let
                                                    mappedDecoder : Elm.Expression
                                                    mappedDecoder =
                                                        Gen.Bytes.Decode.call_.map
                                                            (Elm.val ("Data" ++ (RoutePattern.toModuleName route |> String.join "__")))
                                                            (Elm.value
                                                                { annotation = Nothing
                                                                , importFrom = "Route" :: RoutePattern.toModuleName route
                                                                , name = "w3_decode_Data"
                                                                }
                                                            )

                                                    routeVariant : String
                                                    routeVariant =
                                                        "Route." ++ (RoutePattern.toModuleName route |> String.join "__")
                                                in
                                                if RoutePattern.hasRouteParams route then
                                                    Elm.Case.branch1
                                                        routeVariant
                                                        ( "_", Type.unit )
                                                        (\_ ->
                                                            mappedDecoder
                                                        )

                                                else
                                                    Elm.Case.branch0 routeVariant mappedDecoder
                                            )
                                    )
                            )
                        }
                        |> Elm.withType (Gen.Bytes.Decode.annotation_.decoder (Type.named [] "PageData"))
                )

        pathsToGenerateHandler :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        pathsToGenerateHandler =
            topLevelValue "pathsToGenerateHandler"
                (Gen.ApiRoute.succeed
                    (Gen.DataSource.map2
                        (\pageRoutes apiRoutes ->
                            Elm.Op.append pageRoutes
                                (apiRoutes
                                    |> Gen.List.call_.map (Elm.fn ( "api", Nothing ) (\api -> Elm.Op.append (Elm.string "/") api))
                                )
                                |> Gen.Json.Encode.call_.list Gen.Json.Encode.values_.string
                                |> Gen.Json.Encode.encode 0
                        )
                        (Gen.DataSource.map
                            (Gen.List.call_.map
                                (Elm.fn ( "route", Nothing )
                                    (\route_ ->
                                        Elm.apply
                                            (Elm.value
                                                { name = "toPath"
                                                , importFrom = [ "Route" ]
                                                , annotation = Nothing
                                                }
                                            )
                                            [ route_ ]
                                            |> Gen.Path.toAbsolute
                                    )
                                )
                            )
                            getStaticRoutes.reference
                        )
                        (Elm.Op.cons routePatterns.reference
                            (Elm.Op.cons apiPatterns.reference
                                (Elm.apply (Elm.value { name = "routes", importFrom = [ "Api" ], annotation = Nothing })
                                    [ getStaticRoutes.reference
                                    , fnIgnore (Elm.string "")
                                    ]
                                )
                            )
                            |> Gen.List.call_.map Gen.ApiRoute.values_.getBuildTimeRoutes
                            |> Gen.DataSource.call_.combine
                            |> Gen.DataSource.call_.map Gen.List.values_.concat
                        )
                    )
                    |> Gen.ApiRoute.literal "all-paths.json"
                    |> Gen.ApiRoute.single
                )

        apiPatterns :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        apiPatterns =
            topLevelValue "apiPatterns"
                (Gen.ApiRoute.succeed
                    (Gen.Json.Encode.call_.list
                        Gen.Basics.values_.identity
                        (Elm.apply
                            (Elm.value { name = "routes", importFrom = [ "Api" ], annotation = Nothing })
                            [ getStaticRoutes.reference
                            , fnIgnore (Elm.string "")
                            ]
                            |> Gen.List.call_.map Gen.ApiRoute.values_.toJson
                        )
                        |> Gen.Json.Encode.encode 0
                        |> Gen.DataSource.succeed
                    )
                    |> Gen.ApiRoute.literal "api-patterns.json"
                    |> Gen.ApiRoute.single
                    |> Elm.withType
                        (Gen.ApiRoute.annotation_.apiRoute
                            Gen.ApiRoute.annotation_.response
                        )
                )

        routePatterns :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        routePatterns =
            topLevelValue "routePatterns"
                (Gen.ApiRoute.succeed
                    (Gen.Json.Encode.call_.list
                        (Elm.fn ( "info", Nothing )
                            (\info ->
                                Gen.Json.Encode.object
                                    [ Elm.tuple (Elm.string "kind") (Gen.Json.Encode.call_.string (info |> Elm.get "kind"))
                                    , Elm.tuple (Elm.string "pathPattern") (Gen.Json.Encode.call_.string (info |> Elm.get "pathPattern"))
                                    ]
                            )
                        )
                        (routes
                            |> List.concatMap
                                (\route ->
                                    let
                                        params =
                                            route
                                                |> RoutePattern.toVariantName
                                                |> .params
                                    in
                                    case params |> RoutePattern.repeatWithoutOptionalEnding of
                                        Just repeated ->
                                            [ ( route, repeated ), ( route, params ) ]

                                        Nothing ->
                                            [ ( route, params ) ]
                                )
                            |> List.map
                                (\( route, params ) ->
                                    let
                                        pattern : String
                                        pattern =
                                            "/"
                                                ++ (params
                                                        |> List.map
                                                            (\param ->
                                                                case param of
                                                                    RoutePattern.StaticParam name ->
                                                                        name

                                                                    RoutePattern.DynamicParam name ->
                                                                        ":" ++ name

                                                                    RoutePattern.OptionalParam2 name ->
                                                                        ":" ++ name

                                                                    RoutePattern.OptionalSplatParam2 ->
                                                                        "*"

                                                                    RoutePattern.RequiredSplatParam2 ->
                                                                        "*"
                                                            )
                                                        |> String.join "/"
                                                   )
                                    in
                                    Elm.record
                                        [ ( "pathPattern", Elm.string pattern )
                                        , ( "kind"
                                          , Elm.value
                                                { name = "route"
                                                , importFrom = "Route" :: (route |> RoutePattern.toModuleName)
                                                , annotation = Nothing
                                                }
                                                |> Elm.get "kind"
                                          )
                                        ]
                                )
                            |> Elm.list
                        )
                        |> Gen.Json.Encode.encode 0
                        |> Gen.DataSource.succeed
                    )
                    |> Gen.ApiRoute.literal "route-patterns.json"
                    |> Gen.ApiRoute.single
                    |> Elm.withType
                        (Gen.ApiRoute.annotation_.apiRoute
                            Gen.ApiRoute.annotation_.response
                        )
                )

        globalHeadTags :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        globalHeadTags =
            topLevelValue "globalHeadTags"
                (Elm.Op.cons
                    (Elm.value
                        { importFrom = [ "Site" ]
                        , annotation = Nothing
                        , name = "config"
                        }
                        |> Elm.get "head"
                    )
                    (Elm.apply
                        (Elm.value
                            { importFrom = [ "Api" ]
                            , annotation = Nothing
                            , name = "routes"
                            }
                        )
                        [ getStaticRoutes.reference
                        , Gen.HtmlPrinter.values_.htmlToString
                        ]
                        |> Gen.List.call_.filterMap Gen.ApiRoute.values_.getGlobalHeadTagsDataSource
                    )
                    |> Gen.DataSource.call_.combine
                    |> Gen.DataSource.call_.map Gen.List.values_.concat
                    |> Elm.withType
                        (Gen.DataSource.annotation_.dataSource
                            (Type.list Gen.Head.annotation_.tag)
                        )
                )

        encodeResponse :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        encodeResponse =
            topLevelValue "encodeResponse"
                (Elm.apply
                    (Elm.value
                        { annotation = Nothing
                        , name = "w3_encode_ResponseSketch"
                        , importFrom =
                            [ "Pages", "Internal", "ResponseSketch" ]
                        }
                    )
                    [ Elm.val "w3_encode_PageData"
                    , Elm.val "w3_encode_ActionData"
                    , Elm.value
                        { annotation = Nothing
                        , name = "w3_encode_Data"
                        , importFrom =
                            [ "Shared" ]
                        }
                    ]
                    |> Elm.withType
                        (Type.function
                            [ Type.namedWith [ "Pages", "Internal", "ResponseSketch" ]
                                "ResponseSketch"
                                [ Type.named [] "PageData"
                                , Type.named [] "ActionData"
                                , Type.named [ "Shared" ] "Data"
                                ]
                            ]
                            Gen.Bytes.Encode.annotation_.encoder
                        )
                )

        decodeResponse :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        decodeResponse =
            topLevelValue "decodeResponse"
                (Elm.apply
                    (Elm.value
                        { annotation = Nothing
                        , name = "w3_decode_ResponseSketch"
                        , importFrom =
                            [ "Pages", "Internal", "ResponseSketch" ]
                        }
                    )
                    [ Elm.val "w3_decode_PageData"
                    , Elm.val "w3_decode_ActionData"
                    , Elm.value
                        { annotation = Nothing
                        , name = "w3_decode_Data"
                        , importFrom =
                            [ "Shared" ]
                        }
                    ]
                    |> Elm.withType
                        (Type.namedWith [ "Pages", "Internal", "ResponseSketch" ]
                            "ResponseSketch"
                            [ Type.named [] "PageData"
                            , Type.named [] "ActionData"
                            , Type.named [ "Shared" ] "Data"
                            ]
                            |> Gen.Bytes.Decode.annotation_.decoder
                        )
                )

        getStaticRoutes :
            { declaration : Elm.Declaration
            , reference : Elm.Expression
            , referenceFrom : List String -> Elm.Expression
            }
        getStaticRoutes =
            topLevelValue "getStaticRoutes"
                (Gen.DataSource.combine
                    (routes
                        |> List.map
                            (\route ->
                                Elm.value
                                    { name = "route"
                                    , annotation = Nothing
                                    , importFrom = "Route" :: (route |> RoutePattern.toModuleName)
                                    }
                                    |> Elm.get "staticRoutes"
                                    |> Gen.DataSource.map
                                        (Gen.List.call_.map
                                            (if RoutePattern.hasRouteParams route then
                                                Elm.value
                                                    { annotation = Nothing
                                                    , name =
                                                        (route |> RoutePattern.toModuleName)
                                                            |> String.join "__"
                                                    , importFrom = [ "Route" ]
                                                    }

                                             else
                                                fnIgnore
                                                    (Elm.value
                                                        { annotation = Nothing
                                                        , name =
                                                            (route |> RoutePattern.toModuleName)
                                                                |> String.join "__"
                                                        , importFrom = [ "Route" ]
                                                        }
                                                    )
                                            )
                                        )
                            )
                    )
                    |> Gen.DataSource.call_.map Gen.List.values_.concat
                    |> Elm.withType
                        (Gen.DataSource.annotation_.dataSource
                            (Type.list (Type.named [ "Route" ] "Route"))
                        )
                )
    in
    Elm.file [ "Main" ]
        [ Elm.alias "Model"
            (Type.record
                [ ( "global", Type.named [ "Shared" ] "Model" )
                , ( "page", Type.named [] "PageModel" )
                , ( "current"
                  , Type.maybe
                        (Type.record
                            [ ( "path"
                              , Type.record
                                    [ ( "path", Type.named [ "Path" ] "Path" )
                                    , ( "query", Type.string |> Type.maybe )
                                    , ( "fragment", Type.string |> Type.maybe )
                                    ]
                              )
                            , ( "metadata", Type.maybe (Type.named [ "Route" ] "Route") )
                            , ( "pageUrl", Type.maybe (Type.named [ "Pages", "PageUrl" ] "PageUrl") )
                            ]
                        )
                  )
                ]
            )
        , Elm.customType "PageModel"
            ((routes
                |> List.map
                    (\route ->
                        Elm.variantWith
                            ("Model"
                                ++ (RoutePattern.toModuleName route |> String.join "__")
                            )
                            [ Type.named
                                ("Route"
                                    :: RoutePattern.toModuleName route
                                )
                                "Model"
                            ]
                    )
             )
                ++ [ Elm.variantWith "ModelErrorPage____"
                        [ Type.named [ "ErrorPage" ] "Model" ]
                   , Elm.variant "NotFound"
                   ]
            )
        , Elm.customType "Msg"
            ((routes
                |> List.map
                    (\route ->
                        Elm.variantWith
                            ("Msg"
                                ++ (RoutePattern.toModuleName route |> String.join "__")
                            )
                            [ Type.named
                                ("Route"
                                    :: RoutePattern.toModuleName route
                                )
                                "Msg"
                            ]
                    )
             )
                ++ [ Elm.variantWith "MsgGlobal" [ Type.named [ "Shared" ] "Msg" ]
                   , Elm.variantWith "OnPageChange"
                        [ Type.record
                            [ ( "protocol", Gen.Url.annotation_.protocol )
                            , ( "host", Type.string )
                            , ( "port_", Type.maybe Type.int )
                            , ( "path", pathType )
                            , ( "query", Type.maybe Type.string )
                            , ( "fragment", Type.maybe Type.string )
                            , ( "metadata", Type.maybe (Type.named [ "Route" ] "Route") )
                            ]
                        ]
                   , Elm.variantWith "MsgErrorPage____" [ Type.named [ "ErrorPage" ] "Msg" ]
                   ]
            )
        , Elm.customType "PageData"
            ((routes
                |> List.map
                    (\route ->
                        Elm.variantWith
                            ("Data"
                                ++ (RoutePattern.toModuleName route |> String.join "__")
                            )
                            [ Type.named
                                ("Route"
                                    :: RoutePattern.toModuleName route
                                )
                                "Data"
                            ]
                    )
             )
                ++ [ Elm.variant "Data404NotFoundPage____"
                   , Elm.variantWith "DataErrorPage____" [ Type.named [ "ErrorPage" ] "ErrorPage" ]
                   ]
            )
        , Elm.customType "ActionData"
            (routes
                |> List.map
                    (\route ->
                        Elm.variantWith
                            ("ActionData"
                                ++ (RoutePattern.toModuleName route |> String.join "__")
                            )
                            [ Type.named
                                ("Route"
                                    :: RoutePattern.toModuleName route
                                )
                                "ActionData"
                            ]
                    )
            )
        , Gen.Pages.Internal.Platform.application config.reference
            |> Elm.declaration "main"
            |> expose
        , config.declaration
        , dataForRoute.declaration
        , toTriple.declaration
        , action.declaration
        , fooFn.declaration
        , templateSubscriptions.declaration
        , onActionData.declaration
        , byteEncodePageData.declaration
        , byteDecodePageData.declaration
        , apiPatterns.declaration
        , init.declaration
        , update.declaration
        , initErrorPage.declaration
        , routePatterns.declaration
        , pathsToGenerateHandler.declaration
        , getStaticRoutes.declaration
        , handleRoute.declaration
        , encodeActionData.declaration
        , subscriptions.declaration
        , Elm.portOutgoing "sendPageData"
            (Type.record
                [ ( "oldThing", Gen.Json.Encode.annotation_.value )
                , ( "binaryPageData", Gen.Bytes.annotation_.bytes )
                ]
            )
        , globalHeadTags.declaration
        , encodeResponse.declaration
        , pathPatterns.declaration
        , decodeResponse.declaration
        , Elm.portIncoming "hotReloadData"
            [ Gen.Bytes.annotation_.bytes ]
        , Elm.portOutgoing "toJsPort"
            Gen.Json.Encode.annotation_.value
        , Elm.portIncoming "fromJsPort"
            [ Gen.Json.Decode.annotation_.value ]
        , Elm.portIncoming "gotBatchSub"
            [ Gen.Json.Decode.annotation_.value ]
        ]


routeToSyntaxPattern : RoutePattern -> Elm.Pattern.Pattern (Maybe Elm.Expression)
routeToSyntaxPattern route =
    let
        moduleName : String
        moduleName =
            "Route." ++ (RoutePattern.toModuleName route |> String.join "__")
    in
    if RoutePattern.hasRouteParams route then
        Elm.Pattern.variant1 moduleName
            (Elm.Pattern.var "routeParams" |> Elm.Pattern.map Just)

    else
        Elm.Pattern.variant0 moduleName
            |> Elm.Pattern.map (\() -> Nothing)


applyIdentityTo : Elm.Expression -> Elm.Expression
applyIdentityTo to =
    Elm.apply to [ Gen.Basics.values_.identity ]


todo : Elm.Expression
todo =
    Elm.apply (Elm.val "Debug.todo") [ Elm.string "" ]


pathType : Type.Annotation
pathType =
    Type.named [ "Path" ] "Path"


routePatternToSyntax : RoutePattern -> Elm.Expression
routePatternToSyntax route =
    Gen.Pages.Internal.RoutePattern.make_.routePattern
        { segments =
            route.segments
                |> List.map
                    (\segment ->
                        case segment of
                            RoutePattern.StaticSegment name ->
                                Gen.Pages.Internal.RoutePattern.make_.staticSegment (Elm.string name)

                            RoutePattern.DynamicSegment name ->
                                Gen.Pages.Internal.RoutePattern.make_.dynamicSegment (Elm.string name)
                    )
                |> Elm.list
        , ending =
            route.ending
                |> Maybe.map
                    (\ending ->
                        case ending of
                            RoutePattern.Optional name ->
                                Gen.Pages.Internal.RoutePattern.make_.optional (Elm.string name)

                            RoutePattern.RequiredSplat ->
                                Gen.Pages.Internal.RoutePattern.make_.requiredSplat

                            RoutePattern.OptionalSplat ->
                                Gen.Pages.Internal.RoutePattern.make_.optionalSplat
                    )
                |> Elm.maybe
        }


effectNone =
    Elm.value { annotation = Nothing, importFrom = [ "Effect" ], name = "none" }
