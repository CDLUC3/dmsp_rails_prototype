# frozen_string_literal: true

class DmpsController < ApplicationController
  before_action :set_dmp, only: %i[ show update destroy ]

  # GET /dmps
  def index
    @dmps = Dmp.all
    render json: @dmps.map { |dmp| dmp.to_json }
  end

  # GET /dmps/11.22222/333444555
  def show
    render json: @dmp.to_json
  end

  # POST /dmps
  def create
    @dmp = Dmp.new(**dmp_params)

    if @dmp.save
      render json: @dmp.to_json, status: :created, location: dmp_path(@dmp.dmp_id)
    else
      render json: @dmp.errors, status: :unprocessable_entity
    end
  end

  # PATCH/PUT /dmps/11.22222/333444555
  def update
    if @dmp.update(**dmp_params)
      render json: @dmp.to_json
    else
      render json: @dmp.errors, status: :unprocessable_entity
    end
  end

  # DELETE /dmps/11.22222/333444555
  def destroy
    # If it is registered, tombstone it, otherwise delete it
    if @dmp.registered? ? @dmp.send(:tombstone) : @dmp.delete
      render json: { message: 'ok' }
    else
      render json: @dmp.errors, status: :unprocessable_entity
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_dmp
      @dmp = Dmp.find_by_dmp_id(dmp_id: params[:id], version: params[:version])
    end

    # Only allow a list of trusted parameters through.
    def dmp_params
      params.require(:dmp).permit(:title, :description)
    end
end
