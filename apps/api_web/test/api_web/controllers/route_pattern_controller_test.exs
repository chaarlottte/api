defmodule ApiWeb.RoutePatternControllerTest do
  @moduledoc false
  use ApiWeb.ConnCase

  alias Model.Route
  alias Model.RoutePattern
  alias Model.Trip

  setup %{conn: conn} do
    {:ok, conn: put_req_header(conn, "accept", "application/json")}
  end

  describe "index_data/2" do
    defp new_state!(stops, routes, route_patterns, trips, schedules) do
      State.Stop.new_state(stops)
      State.Route.new_state(routes)
      State.RoutePattern.new_state(route_patterns)
      State.Trip.new_state(trips)
      State.Schedule.new_state(schedules)
      State.RoutesPatternsAtStop.update!()
    end

    test "lists all entries on index by sort order", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: "200"},
        %RoutePattern{id: "rp2", sort_order: "100"}
      ])

      conn = get(conn, route_pattern_path(conn, :index))
      response = json_response(conn, 200)

      assert [
               %{"type" => "route_pattern", "id" => "rp2"},
               %{"type" => "route_pattern", "id" => "rp1"}
             ] = response["data"]
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id",
        canonical: false
      }

      State.RoutePattern.new_state([route_pattern])

      response = get(conn, route_pattern_path(conn, :index))
      assert validate_resp_schema(response, schema, "RoutePatterns")
    end

    test "can filter by multiple ids", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1"},
        %RoutePattern{id: "rp2"},
        %RoutePattern{id: "rp3"}
      ])

      conn = get(conn, route_pattern_path(conn, :index, %{"filter" => %{"id" => "rp1,rp2"}}))

      assert [%{"id" => "rp1"}, %{"id" => "rp2"}] = json_response(conn, 200)["data"]
    end

    test "can filter by route", %{conn: conn} do
      State.Route.new_state([
        %Route{id: "route12"},
        %Route{id: "route3"},
        %Route{id: "route4"}
      ])

      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", route_id: "route12"},
        %RoutePattern{id: "rp2", route_id: "route12"},
        %RoutePattern{id: "rp3", route_id: "route3"},
        %RoutePattern{id: "rp4", route_id: "route4"}
      ])

      State.Trip.new_state([
        %Trip{id: "t1", route_pattern_id: "rp1", route_id: "route12"},
        %Trip{id: "t2", route_pattern_id: "rp2", route_id: "route12"},
        %Trip{id: "t3", route_pattern_id: "rp3", route_id: "route3"},
        %Trip{id: "t4", route_pattern_id: "rp4", route_id: "route4"}
      ])

      conn =
        get(conn, route_pattern_path(conn, :index, %{"filter" => %{"route" => "route12,route3"}}))

      assert [%{"id" => "rp1"}, %{"id" => "rp2"}, %{"id" => "rp3"}] =
               json_response(conn, 200)["data"]
    end

    test "can filter by route and direction", %{conn: conn} do
      State.Route.new_state([
        %Route{id: "route12"},
        %Route{id: "route3"},
        %Route{id: "route4"}
      ])

      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", route_id: "route12", direction_id: 0},
        %RoutePattern{id: "rp2", route_id: "route12", direction_id: 1},
        %RoutePattern{id: "rp3", route_id: "route3", direction_id: 0},
        %RoutePattern{id: "rp4", route_id: "route4", direction_id: 1}
      ])

      State.Trip.new_state([
        %Trip{id: "t1", route_pattern_id: "rp1", route_id: "route12", direction_id: 0},
        %Trip{id: "t2", route_pattern_id: "rp2", route_id: "route12", direction_id: 1},
        %Trip{id: "t3", route_pattern_id: "rp3", route_id: "route3", direction_id: 0},
        %Trip{id: "t4", route_pattern_id: "rp4", route_id: "route4", direction_id: 1}
      ])

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"route" => "route12,route3", "direction_id" => "0"}
          })
        )

      assert [
               %{
                 "id" => "rp1",
                 "relationships" => %{"route" => %{"data" => %{"id" => "route12"}}},
                 "attributes" => %{"direction_id" => 0}
               },
               %{
                 "id" => "rp3",
                 "relationships" => %{"route" => %{"data" => %{"id" => "route3"}}},
                 "attributes" => %{"direction_id" => 0}
               }
             ] = json_response(conn, 200)["data"]
    end

    test "can filter by stop", %{conn: conn} do
      route = %Model.Route{id: "route"}
      route_pattern = %RoutePattern{id: "pattern", route_id: route.id}

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        route_pattern_id: route_pattern.id,
        direction_id: 0
      }

      stop = %Model.Stop{id: "stop"}
      schedule = %Model.Schedule{trip_id: trip.id, stop_id: stop.id, route_id: route.id}
      new_state!([stop], [route], [route_pattern], [trip], [schedule])

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"stop" => "stop"}
          })
        )

      [data] = json_response(conn, 200)["data"]
      assert "pattern" == data["id"]
    end

    test "can filter by stop with legacy stop ID translation", %{conn: conn} do
      route = %Model.Route{id: "route"}
      route_pattern = %RoutePattern{id: "pattern", route_id: route.id}

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        route_pattern_id: route_pattern.id,
        direction_id: 0
      }

      stop = %Model.Stop{id: "place-nubn"}
      schedule = %Model.Schedule{trip_id: trip.id, stop_id: stop.id, route_id: route.id}
      new_state!([stop], [route], [route_pattern], [trip], [schedule])

      response =
        conn
        |> assign(:api_version, "2020-05-01")
        |> get(route_pattern_path(conn, :index, %{"filter" => %{"stop" => "place-dudly"}}))
        |> json_response(200)

      assert hd(response["data"])["id"] == "pattern"

      response =
        conn
        |> assign(:api_version, "2021-01-09")
        |> get(route_pattern_path(conn, :index, %{"filter" => %{"stop" => "place-dudly"}}))
        |> json_response(200)

      assert response["data"] == []
    end

    test "can filter by route, stop and direction", %{conn: conn} do
      route = %Model.Route{id: "route"}
      route_pattern = %RoutePattern{id: "pattern", route_id: route.id}

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        route_pattern_id: route_pattern.id,
        direction_id: 0
      }

      stop = %Model.Stop{id: "stop"}
      schedule = %Model.Schedule{trip_id: trip.id, stop_id: stop.id, route_id: route.id}
      new_state!([stop], [route], [route_pattern], [trip], [schedule])

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"stop" => "stop", "direction_id" => "0"}
          })
        )

      [data] = json_response(conn, 200)["data"]
      assert "pattern" == data["id"]

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"stop" => "stop", "direction_id" => "0", "route" => "route"}
          })
        )

      [data] = json_response(conn, 200)["data"]
      assert "pattern" == data["id"]

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"stop" => "stop", "direction_id" => "1"}
          })
        )

      assert [] == json_response(conn, 200)["data"]

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"stop" => "stop", "direction_id" => "0", "route" => "not_route"}
          })
        )

      assert [] == json_response(conn, 200)["data"]
    end

    defp canonical_test_route_patterns do
      [
        %RoutePattern{
          id: "rp1",
          route_id: "route1",
          direction_id: 0,
          canonical: true,
          typicality: 5
        },
        %RoutePattern{
          id: "rp2",
          route_id: "route1",
          direction_id: 1,
          canonical: true,
          typicality: 5
        },
        %RoutePattern{
          id: "rp3",
          route_id: "route2",
          direction_id: 0,
          canonical: false,
          typicality: 5
        },
        %RoutePattern{
          id: "rp4",
          route_id: "route2",
          direction_id: 1,
          canonical: false,
          typicality: 5
        },
        %RoutePattern{
          id: "rp5",
          route_id: "route3",
          direction_id: 0,
          canonical: false,
          typicality: 5
        },
        %RoutePattern{
          id: "rp6",
          route_id: "route3",
          direction_id: 1,
          canonical: false,
          typicality: 5
        }
      ]
    end

    test "can filter by canonical true", %{conn: conn} do
      State.RoutePattern.new_state(canonical_test_route_patterns())

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"canonical" => true}
          })
        )

      assert [
               %{
                 "id" => "rp1",
                 "attributes" => %{"direction_id" => 0, "canonical" => true}
               },
               %{
                 "id" => "rp2",
                 "attributes" => %{"direction_id" => 1, "canonical" => true}
               }
             ] = json_response(conn, 200)["data"]
    end

    test "can filter by canonical false", %{conn: conn} do
      State.RoutePattern.new_state(canonical_test_route_patterns())

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"canonical" => false}
          })
        )

      assert [
               %{
                 "id" => "rp4",
                 "attributes" => %{"direction_id" => 1, "canonical" => false}
               },
               %{
                 "id" => "rp5",
                 "attributes" => %{"direction_id" => 0, "canonical" => false}
               },
               %{
                 "id" => "rp3",
                 "attributes" => %{"direction_id" => 0, "canonical" => false}
               },
               %{
                 "id" => "rp6",
                 "attributes" => %{"direction_id" => 1, "canonical" => false}
               }
             ] = json_response(conn, 200)["data"]
    end

    test "filtering by canonical null is treated the same as it not being included", %{conn: conn} do
      State.RoutePattern.new_state(canonical_test_route_patterns())

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, %{
            "filter" => %{"canonical" => nil}
          })
        )

      assert [
               %{
                 "id" => "rp4",
                 "attributes" => %{"direction_id" => 1, "canonical" => false}
               },
               %{
                 "id" => "rp5",
                 "attributes" => %{"direction_id" => 0, "canonical" => false}
               },
               %{
                 "id" => "rp1",
                 "attributes" => %{"direction_id" => 0, "canonical" => true}
               },
               %{
                 "id" => "rp3",
                 "attributes" => %{"direction_id" => 0, "canonical" => false}
               },
               %{
                 "id" => "rp6",
                 "attributes" => %{"direction_id" => 1, "canonical" => false}
               },
               %{
                 "id" => "rp2",
                 "attributes" => %{"direction_id" => 1, "canonical" => true}
               }
             ] = json_response(conn, 200)["data"]
    end

    test "can include route and trip", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp", route_id: "routeid", representative_trip_id: "tripid"}
      ])

      State.Route.new_state([
        %Route{id: "routeid"}
      ])

      State.Trip.new_state([
        %Trip{id: "tripid"}
      ])

      conn =
        get(
          conn,
          route_pattern_path(conn, :index, include: "route,representative_trip")
        )

      response = json_response(conn, 200)
      assert [%{"type" => "route_pattern", "id" => "rp"}] = response["data"]

      assert [
               %{"type" => "route", "id" => "routeid"},
               %{"type" => "trip", "id" => "tripid"}
             ] = response["included"]

      [%{"relationships" => relationships}] = response["data"]

      assert %{
               "representative_trip" => %{"data" => %{"id" => "tripid", "type" => "trip"}},
               "route" => %{"data" => %{"id" => "routeid", "type" => "route"}}
             } == relationships
    end

    test "pagination", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: 1},
        %RoutePattern{id: "rp2", sort_order: 2},
        %RoutePattern{id: "rp3", sort_order: 3}
      ])

      params = %{"page" => %{"offset" => 2, "limit" => 1}}
      conn = get(conn, route_pattern_path(conn, :index, params))

      response = json_response(conn, 200)
      assert [%{"id" => "rp3"}] = response["data"]
    end

    test "pagination can override default ordering", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: 1},
        %RoutePattern{id: "rp2", sort_order: 2},
        %RoutePattern{id: "rp3", sort_order: 3}
      ])

      params = %{"page" => %{"offset" => 2, "limit" => 1}, "sort" => "-sort_order"}
      conn = get(conn, route_pattern_path(conn, :index, params))

      response = json_response(conn, 200)
      assert [%{"id" => "rp1"}] = response["data"]
    end

    test "returns 404 for newer API keys and old URL", %{swagger_schema: schema, conn: conn} do
      conn = assign(conn, :api_version, "2019-07-01")
      response = get(conn, "/route-patterns/")
      assert json_response(response, 404)
      assert validate_resp_schema(response, schema, "NotFound")
    end

    test "can limit returned fields", %{conn: conn} do
      State.RoutePattern.new_state([
        %RoutePattern{id: "rp1", sort_order: 1},
        %RoutePattern{id: "rp2", sort_order: 2},
        %RoutePattern{id: "rp3", sort_order: 3}
      ])

      params = %{"fields" => %{"route_pattern" => "sort_order"}}
      conn = get(conn, route_pattern_path(conn, :index, params))

      response = json_response(conn, 200)
      attrs = Enum.map(response["data"], fn rp -> rp["attributes"] end)

      assert [%{"sort_order" => 1}, %{"sort_order" => 2}, %{"sort_order" => 3}] = attrs
    end

    test "can filter by date", %{conn: base_conn} do
      today = Parse.Time.service_date()
      bad_date = Date.add(today, 2)

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      route = %Model.Route{id: "route"}
      route_pattern = %Model.RoutePattern{id: "rp1", route_id: "route"}

      trip = %Model.Trip{
        id: "trip",
        route_id: route.id,
        service_id: service.id,
        route_pattern_id: route_pattern.id
      }

      State.Service.new_state([service])
      State.Route.new_state([route])
      State.RoutePattern.new_state([route_pattern])
      State.Trip.new_state([trip])
      State.Trip.reset_gather()
      State.RoutesByService.update!()

      today_iso = Date.to_iso8601(today)
      bad_date_iso = Date.to_iso8601(bad_date)

      params = %{"filter" => %{"date" => today_iso}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern] == data

      params = put_in(params["filter"]["date"], bad_date_iso)
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [] == data

      params = %{"filter" => %{"date" => ""}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern] == data

      params = %{"filter" => %{"date" => "invalid"}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern] == data
    end

    test "can filter by date and route(s)", %{conn: base_conn} do
      today = Parse.Time.service_date()
      bad_date = Date.add(today, 2)

      service = %Model.Service{
        id: "service",
        start_date: today,
        end_date: today,
        added_dates: [today]
      }

      future_service = %Model.Service{
        id: "future_service",
        start_date: bad_date,
        end_date: bad_date,
        added_dates: [bad_date]
      }

      route1 = %Model.Route{id: "route1"}
      route2 = %Model.Route{id: "route2"}
      route3 = %Model.Route{id: "route3"}
      route_pattern1 = %Model.RoutePattern{id: "rp1", route_id: route1.id, canonical: false}
      route_pattern2 = %Model.RoutePattern{id: "rp2", route_id: route2.id, canonical: false}
      route_pattern3 = %Model.RoutePattern{id: "rp3", route_id: route3.id, canonical: true}

      route_pattern4 = %Model.RoutePattern{
        id: "rp4",
        route_id: route3.id,
        canonical: false,
        direction_id: 0
      }

      route_pattern5 = %Model.RoutePattern{
        id: "rp5",
        route_id: route3.id,
        canonical: false,
        direction_id: 1
      }

      trip1 = %Model.Trip{
        id: "trip1",
        route_id: route1.id,
        service_id: service.id,
        route_pattern_id: route_pattern1.id
      }

      trip2 = %Model.Trip{
        id: "trip2",
        route_id: route2.id,
        service_id: future_service.id,
        route_pattern_id: route_pattern2.id
      }

      trip3 = %Model.Trip{
        id: "trip3",
        route_id: route3.id,
        service_id: service.id,
        route_pattern_id: route_pattern3.id
      }

      trip4 = %Model.Trip{
        id: "trip4",
        route_id: route3.id,
        direction_id: 0,
        service_id: future_service.id,
        route_pattern_id: route_pattern4.id
      }

      trip5 = %Model.Trip{
        id: "trip5",
        route_id: route3.id,
        direction_id: 1,
        service_id: future_service.id,
        route_pattern_id: route_pattern5.id
      }

      trip6 = %Model.Trip{
        id: "trip6",
        route_id: route1.id,
        service_id: service.id,
        route_pattern_id: route_pattern1.id
      }

      trip7 = %Model.Trip{
        id: "trip7",
        route_id: route1.id,
        service_id: service.id,
        route_pattern_id: route_pattern1.id
      }

      State.Service.new_state([service, future_service])
      State.Route.new_state([route1, route2, route3])

      State.RoutePattern.new_state([
        route_pattern1,
        route_pattern2,
        route_pattern3,
        route_pattern4,
        route_pattern5
      ])

      State.Trip.new_state([trip1, trip2, trip3, trip4, trip5, trip6, trip7])
      State.Trip.reset_gather()
      State.RoutesByService.update!()

      today_iso = Date.to_iso8601(today)
      future_date_iso = Date.to_iso8601(bad_date)

      params = %{"filter" => %{"date" => today_iso}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern1, route_pattern3] == data

      params = %{"filter" => %{"date" => today_iso, "canonical" => "false"}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern1] == data

      params = %{"filter" => %{"date" => today_iso, "canonical" => "true"}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern3] == data

      params = %{"filter" => %{"date" => today_iso, "route" => "route1,route2"}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern1] == data

      params = put_in(params["filter"]["route"], "route3,route4,Red,Blue")
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern3] == data

      params = %{"filter" => %{"date" => future_date_iso, "route" => "route1,route2,route3"}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern2, route_pattern4, route_pattern5] == data

      params = %{
        "filter" => %{
          "date" => future_date_iso,
          "route" => "route1,route2,route3",
          "direction_id" => "0"
        }
      }

      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern4] == data

      params = %{
        "filter" => %{
          "date" => future_date_iso,
          "route" => "route1,route2,route3",
          "direction_id" => "1"
        }
      }

      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern5] == data

      params = %{"filter" => %{"date" => today_iso, "route" => ""}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern1, route_pattern3] == data

      params = %{"filter" => %{"date" => today_iso, "route" => nil}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern1, route_pattern3] == data

      params = %{"filter" => %{"date" => today_iso, "id" => "rp1,rp2"}}
      data = ApiWeb.RoutePatternController.index_data(base_conn, params)
      assert [route_pattern1] == data
    end
  end

  describe "show" do
    test "shows chosen resource", %{conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id",
        canonical: false
      }

      State.RoutePattern.new_state([route_pattern])
      conn = get(conn, route_pattern_path(conn, :show, route_pattern))

      assert json_response(conn, 200)["data"] == %{
               "type" => "route_pattern",
               "id" => "route pattern id",
               "attributes" => %{
                 "direction_id" => 0,
                 "name" => "route pattern name",
                 "time_desc" => nil,
                 "typicality" => 1,
                 "sort_order" => 101,
                 "canonical" => false
               },
               "links" => %{
                 "self" => "/route_patterns/route%20pattern%20id"
               },
               "relationships" => %{
                 "route" => %{
                   "data" => %{
                     "id" => "route id",
                     "type" => "route"
                   }
                 },
                 "representative_trip" => %{
                   "data" => %{
                     "id" => "trip id",
                     "type" => "trip"
                   }
                 }
               }
             }
    end

    test "does not allow filtering", %{conn: conn} do
      route_pattern = %RoutePattern{id: "1"}
      State.RoutePattern.new_state([route_pattern])

      conn = get(conn, route_pattern_path(conn, :show, route_pattern, %{"filter[route]" => "1"}))
      assert json_response(conn, 400)
    end

    test "returns an error with invalid includes", %{conn: conn} do
      conn = get(conn, route_pattern_path(conn, :show, "id"), include: "invalid")

      assert get_in(json_response(conn, 400), ["errors", Access.at(0), "source", "parameter"]) ==
               "include"
    end

    test "conforms to swagger response", %{swagger_schema: schema, conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id",
        canonical: false
      }

      State.RoutePattern.new_state([route_pattern])
      response = get(conn, route_pattern_path(conn, :show, route_pattern))

      assert validate_resp_schema(response, schema, "RoutePattern")
    end

    test "does not show resource and returns JSON-API error document when id is nonexistent", %{
      conn: conn,
      swagger_schema: swagger_shema
    } do
      conn = get(conn, route_pattern_path(conn, :show, -1))

      assert json_response(conn, 404)
      assert validate_resp_schema(conn, swagger_shema, "NotFound")
    end

    test "returns 404 for newer API keys and old URL", %{swagger_schema: schema, conn: conn} do
      route_pattern = %RoutePattern{id: "1"}
      State.RoutePattern.new_state([route_pattern])
      conn = assign(conn, :api_version, "2019-07-01")
      response = get(conn, "/route-patterns/1")
      assert json_response(response, 404)
      assert validate_resp_schema(response, schema, "NotFound")
    end

    test "allows limiting returned fields", %{conn: conn} do
      route_pattern = %RoutePattern{
        id: "route pattern id",
        route_id: "route id",
        direction_id: 0,
        name: "route pattern name",
        time_desc: nil,
        typicality: 1,
        sort_order: 101,
        representative_trip_id: "trip id",
        canonical: false
      }

      State.RoutePattern.new_state([route_pattern])

      conn =
        get(
          conn,
          route_pattern_path(conn, :show, route_pattern, %{
            "fields[route_pattern]" => "sort_order"
          })
        )

      assert json_response(conn, 200)["data"]["attributes"] == %{"sort_order" => 101}
    end
  end

  describe "swagger_path" do
    test "swagger_path_index generates docs for GET /route_patterns" do
      assert %{"/route_patterns" => %{"get" => %{"responses" => %{"200" => %{}}}}} =
               ApiWeb.RoutePatternController.swagger_path_index(%{})
    end

    test "swagger_path_show generates docs for GET /route_patterns/{id}" do
      assert %{
               "/route_patterns/{id}" => %{
                 "get" => %{
                   "responses" => %{
                     "200" => %{},
                     "404" => %{}
                   }
                 }
               }
             } = ApiWeb.RoutePatternController.swagger_path_show(%{})
    end
  end
end
