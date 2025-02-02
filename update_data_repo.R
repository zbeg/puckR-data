##  Updating the puckR data repo

#devtools::install_github("zbeg/puckR")

# get current season data
pbp <- puckR::load_pbp(shift_events = TRUE)

# check for missing shift data in certain games
ids_to_pull <- pbp |>
  dplyr::filter(period == 3) |>
  dplyr::group_by(game_id) |>
  dplyr::summarize(changes = sum(event_type == "CHANGE")) |>
  dplyr::filter(changes == 0) |>
  dplyr::pull(game_id)

# scrape multiple games with missing data

if(length(ids_to_pull) > 0){
  pbp_day <- purrr::map_dfr(
    .x = ids_to_pull,
    ~puckR::scrape_game(.x)
  )

  # check to see if it actually worked
  pbp_day |>
    dplyr::filter(period == 3) |>
    dplyr::group_by(game_id) |>
    dplyr::summarize(changes = sum(event_type == "CHANGE")) |>
    dplyr::filter(changes == 0)
  # should return a tibble with 0 rows
}

# getting the reverse in function
library(puckR)

# combine
pbp_updated <- dplyr::bind_rows(
  dplyr::filter(pbp, game_id %not_in% ids_to_pull),
  pbp_day
) |>
  dplyr::distinct()

# scraping whole season up to a point
#games <- puckR::get_game_ids(season = 2023)

#games <- dplyr::filter(games, date < Sys.Date())

#pbp_updated <- purrr::map_dfr(
#  .x = games$game_id,
#  ~puckR::scrape_game(.x)
#)

if(is.null(pbp) & nrow(pbp_updated) > 0){
  # first save of the season
  new_data <- TRUE
} else if(!is.null(pbp)){
  # season already begun, some data already exists
  # check to see if new games were played, otherwise no need to save
  if(nrow(pbp_updated) > nrow(pbp)){
    # new games added
    new_data <- TRUE
  } else {
    # no new games
    new_data <- FALSE
  }
} else {
  # season not started yet
  new_data <- FALSE
}

if(new_data){
  # new games added, create save file
  season_first <- substr(dplyr::last(pbp_updated$season), 1,4)
  season_last <- substr(dplyr::last(pbp_updated$season), 7,8)

  filename <- glue::glue("data/play_by_play_{season_first}_{season_last}")

  # add smaller version w/o line change events
  pbp_lite <- pbp_updated |>
    dplyr::filter(event_type != "CHANGE")

  pbp_updated |> saveRDS(glue::glue("{filename}.rds"))
  pbp_lite |> saveRDS(glue::glue("{filename}_lite.rds"))
  pbp_updated |> crunch::write.csv.gz(glue::glue("{filename}.csv.gz"))
  pbp_lite |> crunch::write.csv.gz(glue::glue("{filename}_lite.csv.gz"))

  # push to github
  repo <- git2r::repository(getwd())

  git2r::add(repo, glue::glue("{filename}.rds"))
  git2r::add(repo, glue::glue("{filename}.csv.gz"))
  git2r::add(repo, glue::glue("{filename}_lite.rds"))
  git2r::add(repo, glue::glue("{filename}_lite.csv.gz"))

  #git2r::pull(repo)

  git2r::commit(repo, message = glue::glue("Data updated: {Sys.time()}"))

  git2r::push(repo, credentials = git2r::cred_token())
}
