##  Updating the puckR data repo

install.packages(c("dplyr","glue","crunch","remotes"))
remotes::install_github("zbeg/puckR")

# get current season data
pbp <- puckR::load_pbp(shift_events = TRUE)

# get day's pbp data
#   running for yesterday, because this code runs after midnight
pbp_day <- puckR::scrape_day(Sys.Date()-1)

`%not_in%` <- puckR::`%not_in%`

# make sure we're not double loading some games
pbp_day <- dplyr::filter(pbp_day, game_id %not_in% unique(pbp$game_id))

# combine
pbp_updated <- dplyr::bind_rows(
  pbp,
  pbp_day |> dplyr::mutate(season_type = as.character(season_type))
  ) |>
  # another check to make sure there's no doubled up plays
  dplyr::distinct()

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
