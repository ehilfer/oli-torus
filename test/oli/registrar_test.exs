defmodule Oli.RegistrarTest do
  use Oli.DataCase

  alias Oli.Activities

  describe "activity registration" do
    test "register_local_activities/0 registers", _ do
      registrations = Activities.list_activity_registrations()
      assert length(registrations) == 7

      r = Enum.at(registrations, 1)

      assert r.title == "Check All That Apply"

      assert r.description ==
               "A traditional check all that apply question with one correct answer"

      assert r.authoring_script == "oli_check_all_that_apply_authoring.js"
      assert r.delivery_script == "oli_check_all_that_apply_delivery.js"
      assert r.authoring_element == "oli-check-all-that-apply-authoring"
      assert r.delivery_element == "oli-check-all-that-apply-delivery"
      assert r.globally_available == true
    end

    test "create_registered_activity_map/0 creates correctly", _ do
      map = Activities.create_registered_activity_map()

      assert Map.keys(map) |> length == 7

      r = Map.get(map, "oli_check_all_that_apply")

      assert r.slug == "oli_check_all_that_apply"

      assert r.description ==
               "A traditional check all that apply question with one correct answer"

      assert r.friendlyName == "Check All That Apply"
      assert r.authoringElement == "oli-check-all-that-apply-authoring"
      assert r.deliveryElement == "oli-check-all-that-apply-delivery"
      assert r.globallyAvailable == true
    end
  end
end
