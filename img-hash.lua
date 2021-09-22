-- Description: Calculate perceptual image hashes
-- Version: 0.1.0
-- License: GPL-3.0
-- Source: images

function run(arg)
    img_load(arg['value'])
    if last_err() then
        -- not an image
        return clear_err()
    end

    local ahash = img_ahash(arg['value'])
    debug(ahash)

    local dhash = img_dhash(arg['value'])
    debug(dhash)

    local phash = img_phash(arg['value'])
    debug(phash)

    db_update('image', arg, {
        ahash=ahash,
        dhash=dhash,
        phash=phash,
    })
end
