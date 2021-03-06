
library(tidyverse)
library(readxl)
library(here)
library(fs)
library(furrr)

future::plan(multiprocess)

# Find/unzip data ---------------------------------------------------------

# find paths to excel and zip files downloaded from KoBo website (these should be together with this script in same folder)
excel <- dir_ls(path = here(), glob = '*.xlsx')
zip <- dir_ls(path = here(), glob = '*.zip')

# unzip the photos
unzip(zip, exdir = here())

# delete zip file now
zip %>%
  file_delete()


# read in banding data and image paths and join -------------------------------------------

dat <- read_excel(excel)

# grab relevant columns (band number, transmitter ID if no band, and photo types)
dat <- dat %>%
  select(markerID, date, tailPhoto, frontPopsiclePhoto, 
         backPopsiclePhoto, frontWingPhoto, backWingPhoto, otherPhoto)

# change format so photo columns become variable in column 'photo_type'
dat <- dat %>% 
  gather(key = "photo_type", value = "fileName", 3:8) %>%
  filter(!is.na(fileName)) %>% # get rid of NA's (missing or not taken photos)
  arrange(markerID, photo_type) # organize by bird and photo type

# create tibble of photos to be named
rawPhotos <- dir_ls(path = here(), glob = '*.jpg', recurse = TRUE) %>%
  as_tibble() %>%
  rename(path = value) %>%
  mutate(fileName = basename(path))

# join photos with banding data
dat <- dat %>%
  left_join(., rawPhotos) %>%
  select(-fileName)


# now loop through each bird and type of photo -------------------------

# adapted from function for naming images and reading links: https://stackoverflow.com/questions/54262620/downloading-images-using-curl-library-in-a-loop-over-data-frame
rename_photos <- as_mapper(~file_move(path = ..4, 
                                      new_path = str_c(here('renamed_images'), '/', ..1, "_", ..2, "_", ..3, ".jpg")))

# create a folder to put renamed images in
dir_create(here('renamed_images'))

# rename jpgs and put in 'renamed_images' folder using purrr::pmap_chr
dat %>%
  future_pmap_chr(rename_photos)
