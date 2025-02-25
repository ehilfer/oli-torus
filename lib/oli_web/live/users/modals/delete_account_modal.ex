defmodule OliWeb.Accounts.Modals.DeleteAccountModal do
  use Phoenix.LiveComponent
  use Phoenix.HTML

  def render(assigns) do
    ~L"""
    <div class="modal fade show" id="<%= @id %>" tabindex="-1" role="dialog" aria-hidden="true" phx-hook="ModalLaunch">
      <div class="modal-dialog" role="document">
        <div class="modal-content">
            <div class="modal-header">
              <h5 class="modal-title">Delete Account</h5>
              <button type="button" class="close" data-dismiss="modal" aria-label="Close">
                <span aria-hidden="true">&times;</span>
              </button>
            </div>
            <div class="modal-body">
              <p class="mb-4">Are you sure you want to delete account <b><%= @user.email %></b>?</p>
            </div>
            <div class="modal-footer">
              <button type="button" class="btn btn-secondary" data-dismiss="modal">Cancel</button>
              <button
                phx-click="delete_account"
                phx-key="enter"
                phx-value-id="<%= @user.id %>"
                class="btn btn-danger">
                Delete
              </button>
            </div>
        </div>
      </div>
    </div>
    """
  end
end
