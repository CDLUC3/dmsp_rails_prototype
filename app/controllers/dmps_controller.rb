# frozen_string_literal: true

class DmpsController < ApplicationController
  before_action :set_dmp, only: %i[ show update destroy ]

  # GET /dmps
  def index
    @dmps = Dmp.all
    render json: @dmps
  end

  # GET /dmps/11.22222/333444555
  def show
    render json: @dmp
  end

  # POST /dmps
  def create
    @dmp = Dmp.new(**dmp_params)

    if @dmp.save
      render json: @dmp, status: :created, location: @dmp
    else
      render json: @dmp.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /dmps/11.22222/333444555
  def update
    if @dmp.update(**dmp_params)
      render json: @dmp
    else
      render json: @dmp.errors, status: :unprocessable_entity
    end
  end

  # DELETE /dmps/11.22222/333444555
  def destroy
    @dmp.destroy!
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dmp
      @dmp = Dmp.new(**{ dmp_id: params[:id]})
    end

    # Only allow a list of trusted parameters through.
    def dmp_params
      params.require(:dmp).permit(:title, :description)
    end
end
