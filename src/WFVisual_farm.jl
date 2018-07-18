#=##############################################################################
# DESCRIPTION
    Class of wind turbine geometry.
# AUTHORSHIP
  * Author    : Eduardo J Alvarez
  * Email     : Edo.AlvarezR@gmail.com
  * Created   : Jul 2018
  * License   : MIT License
=###############################################################################

################################################################################
# WIND FARM
################################################################################

function generate_windfarm(D::Array{T,1}, H::Array{T,1}, N::Array{Int64,1},
                          x::Array{T,1}, y::Array{T,1}, z::Array{T,1},
                          glob_yaw::Array{T,1}, perimeter::Array{Array{T, 1}, 1},
                          wake;
                          # TURBINE GEOMETRY OPTIONS
                          hub::Array{String,1}=String[],
                          tower::Array{String,1}=String[],
                          blade::Array{String,1}=String[],
                          data_path::String=def_data_path,
                          # PERIMETER AND FLUID DOMAIN OPTIONS
                          NDIVSx=50, NDIVSy=50, NDIVSz=50,
                          z_min="automatic", z_max="automatic",
                          # PERIMETER SPLINE OPTIONS
                          verify_spline::Bool=true,
                          spl_s=0.001, spl_k="automatic",
                          # FILE OPTIONS
                          save_path=nothing, file_name="mywindfarm",
                          paraview=true
                         ) where{T<:Real}

  windfarm = generate_layout(D, H, N, x, y, z, glob_yaw;
                                  hub=hub, tower=tower, blade=blade,
                                  data_path=data_path, save_path=nothing)

  perimeter_grid = generate_perimetergrid(perimeter, NDIVSx, NDIVSy, 0;
                                      verify_spline=verify_spline, spl_s=spl_s,
                                      spl_k=spl_k, save_path=nothing)

  _zmin = z_min=="automatic" ? 0 : z_min
  _zmax = z_max=="automatic" ? maximum(H) + 1.25*maximum(D)/2 : z_max

  fdom = generate_perimetergrid(perimeter,
                                    NDIVSx, NDIVSy, NDIVSz;
                                    z_min=_zmin, z_max=_zmax,
                                    verify_spline=false,
                                    spl_s=spl_s, spl_k=spl_k,
                                    save_path=nothing,
                                  )

  gt.calculate_field(fdom, wake, "wake", "vector", "node")


  if save_path!=nothing
    gt.save(windfarm, file_name; path=save_path)
    gt.save(perimeter_grid, file_name*"_perimeter"; path=save_path)
    gt.save(fdom, file_name*"_fdom"; path=save_path)

    if paraview
      strn = ""
      for i in 1:size(D,1)
        strn *= file_name*"_turbine$(i)_tower.vtk;"
        strn *= file_name*"_turbine$(i)_rotor_hub.vtk;"
        for j in 1:N[i]
          strn *= file_name*"_turbine$(i)_rotor_blade$(j).vtk;"
        end
      end

      strn *= file_name*"_perimeter.vtk;"
      strn *= file_name*"_fdom.vtk;"

      run(`paraview --data=$save_path/$strn`)
    end

  end

  return (windfarm, perimeter, fdom)
end

"""
`generate_layout(D::Array{T,1}, H::Array{T,1}, N::Array{Int64,1},
                          x::Array{T,1}, y::Array{T,1}, z::Array{T,1},
                          glob_yaw::Array{T,1};
                          # TURBINE GEOMETRY OPTIONS
                          hub::Array{String,1}=String[],
                          tower::Array{String,1}=String[],
                          blade::Array{String,1}=String[],
                          data_path::String=def_data_path,
                          # FILE OPTIONS
                          save_path=nothing, file_name="windfarm",
                          paraview=true
                         ) where{T<:Real}`

  Generates and returns a wind farm layout consisting of a MultiGrid object
containing every turbine at the indicated position `x,y,z`, and the given
geometry `D,H,N` and orientation `glob_yaw`.

  **Arguments**
  * `D::Array{Float64,1}`         : Rotor diameter of every turbine.
  * `H::Array{Float64,1}`         : Tower height of every turbine.
  * `N::Array{Float64,1}`         : Number of blades of every turbine.
  * `x::Array{Float64,1}`         : x-position of the every turbine base.
  * `y::Array{Float64,1}`         : y-position of the every turbine base.
  * `z::Array{Float64,1}`         : z-position of the every turbine base.
  * `glob_yaw::Array{Float64,1}`  : Angle of the plane of rotation relative to
                                    the x-axis of the global coordinate system
                                    IN DEGREES.

"""
function generate_layout(D::Array{T,1}, H::Array{T,1}, N::Array{Int64,1},
                          x::Array{T,1}, y::Array{T,1}, z::Array{T,1},
                          glob_yaw::Array{T,1};
                          # TURBINE GEOMETRY OPTIONS
                          hub::Array{String,1}=String[],
                          tower::Array{String,1}=String[],
                          blade::Array{String,1}=String[],
                          data_path::String=def_data_path,
                          # FILE OPTIONS
                          save_path=nothing, file_name="windfarm",
                          paraview=true
                         ) where{T<:Real}

  nturbines = size(D, 1)        # Number of turbines

  # Default turbine geometry
  if size(hub,1)==0
    hub = ["hub" for i in 1:nturbines]
  end
  if size(tower,1)==0
    tower = ["tower1" for i in 1:nturbines]
  end
  if size(blade,1)==0
    blade = ["NREL5MW" for i in 1:nturbines]
  end

  # Generates layout
  windfarm = gt.MultiGrid(3)

  for i in 1:nturbines
    # Generate wind turbine geometry
    turbine = generate_windturbine(D[i]/2, H[i], blade[i], hub[i], tower[i];
                                    nblades=N[i], data_path=data_path,
                                    save_path=nothing)

    # Places it at the location and orientation
    Oaxis = gt.rotation_matrix(glob_yaw[i], 0, 0)
    gt.lintransform!(turbine, Oaxis, [x[i], y[i], z[i]])

    # Adds it to the farm
    gt.addgrid(windfarm, "turbine$i", turbine)
  end

  if save_path!=nothing
    gt.save(windfarm, file_name; path=save_path)

    if paraview
      strn = ""
      for i in 1:nturbines
        strn *= file_name*"_turbine$(i)_tower.vtk;"
        strn *= file_name*"_turbine$(i)_rotor_hub.vtk;"
        for j in 1:N[i]
          strn *= file_name*"_turbine$(i)_rotor_blade$(j).vtk;"
        end
      end

      run(`paraview --data=$save_path/$strn`)
    end

  end

  return windfarm::gt.MultiGrid
end

"""
`generate_perimetergrid(perimeter::Array{Array{T, 1}, 1},
                                  NDIVSx, NDIVSy, NDIVSz;
                                  z_min::Real=0, z_max::Real=0,
                                  # SPLINE OPTIONS
                                  verify_spline::Bool=true,
                                  spl_s=0.001, spl_k="automatic",
                                  # FILE OPTIONS
                                  save_path=nothing, file_name="perimeter",
                                  paraview=true
                                )`

  Generates the perimeter grid with `perimeter` the array of points of the
  contour (must be a closed contour), and `NDIVS_` the number of cells in
  each parametric dimension (give it `NDIVSz=0` for a flat surface, otherwise
  it'll generate a volumetric grid between `z_min` and `z_max`).
"""
function generate_perimetergrid(perimeter::Array{Array{T, 1}, 1},
                                  NDIVSx, NDIVSy, NDIVSz;
                                  z_min::Real=0, z_max::Real=0,
                                  # SPLINE OPTIONS
                                  verify_spline::Bool=true,
                                  spl_s=0.001, spl_k="automatic",
                                  # FILE OPTIONS
                                  save_path=nothing, file_name="perimeter",
                                  paraview=true
                                ) where{T<:Real}

  # Error cases
  multidiscrtype = Array{Tuple{Float64,Int64,Float64,Bool},1}
  if typeof(NDIVSx)==Int64
    nz = NDIVSz
  elseif typeof(NDIVSz)==multidiscrtype
    nz = 0
    for sec in NDIVSz
      nz += sec[2]
    end
  else
    error("Expected `NDIVSz` to be type $(Int64) or $MultiDiscrType,"*
            " got $(typeof(NDIVSz)).")
  end

  # --------- REPARAMETERIZES THE PERIMETER ---------------------------
  org_x = [p[1] for p in perimeter]
  org_y = [p[2] for p in perimeter]

  # Separate upper and lower sides to make the contour injective in x
  upper, lower = gt.splitcontour(org_x, org_y)

  # Parameterize both sides independently
  fun_upper = gt.parameterize(upper[1], upper[2], zeros(upper[1]); inj_var=1,
                                                      s=spl_s, kspl=spl_k)
  fun_lower = gt.parameterize(lower[1], lower[2], zeros(lower[1]); inj_var=1,
                                                      s=spl_s, kspl=spl_k)
  # Discretizes both sides
  if NDIVSx==multidiscrtype
    new_upper = gt.multidiscretize(fun_upper, 0, 1, NDIVSx)
    new_lower = gt.multidiscretize(fun_lower, 0, 1, NDIVSx)
  else
    new_upper = gt.discretize(fun_upper, 0, 1, NDIVSx, 1.0)
    new_lower = gt.discretize(fun_lower, 0, 1, NDIVSx, 1.0)
  end


  # ----------------- SPLINE VERIFICATION --------------------------------------
  if verify_spline
    new_points = vcat(reverse(new_upper), new_lower)
    new_x = [p[1] for p in new_points]
    new_y = [p[2] for p in new_points]
    plt.plot(org_x, org_y, "--^k", label="Original", alpha=0.5)
    plt.plot(new_x, new_y, ":.b", label="Parameterized")
    plt.xlabel(plt.L"x")
    plt.ylabel(plt.L"y")
    plt.legend(loc="best")
    plt.grid(true, color="0.8", linestyle="--")
  end

  # --------- GRIDS THE INSIDE OF THE PERIMETER ---------------------
  # Parametric grid
  P_min = zeros(3)
  P_max = [1, 1, 1*(nz!=0)]
  param_grid = gt.Grid(P_min, P_max, [NDIVSx, NDIVSy, NDIVSz])

  function my_space_transform(X, ind)
      i = ind[1]                      # Arc length point
      w = X[2]                        # Weight
      z = z_min + X[3]*(z_max-z_min)  # z-position

      Y = new_lower[i] + w*(new_upper[i]-new_lower[i])
      Y[3] = z

      return Y
  end

  # Applies the space transformation to the parametric grid
  gt.transform3!(param_grid, my_space_transform)

  if save_path!=nothing
    gt.save(param_grid, file_name; path=save_path)

    if paraview
      strn = file_name*".vtk"
      run(`paraview --data=$save_path/$strn`)
    end

  end

  return param_grid::gt.Grid
end
# ------------ END OF WIND FARM ------------------------------------------------