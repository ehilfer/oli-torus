defmodule OliWeb.InstructorDeliveryView do
  use OliWeb, :view

  def page_route(conn, context_id, slug) do
    Routes.instructor_delivery_path(conn, :page, context_id, slug)
  end
end
