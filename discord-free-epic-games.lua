-- Description: Notify a discord webhook about free epic games
-- Version: 0.1.0
-- License: GPL-3.0

function get_image_tall(imgs)
    for i=1, #imgs do
        if imgs[i]['type'] == 'OfferImageTall' then
            return imgs[i]['url']
        end
    end
end

function notify(url, o)
    local session = http_mksession()
    local req = http_request(session, 'POST', url, {
        json=o,
    })
    local r = http_fetch(req)
    debug(r)
end

function run()
    local discord_webhook = getopt('hook')
    if not discord_webhook then
        return 'Missing -o hook= option'
    end

    local url = 'https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=en-US&country=US&allowCountries=US'

    local session = http_mksession()
    local req = http_request(session, 'GET', url, {
        json=data,
    })
    local d = http_fetch_json(req)
    if last_err() then return end

    local list = d['data']['Catalog']['searchStore']['elements']
    for i=1, #list do
        local item = list[i]
        local offer = item['promotions']['promotionalOffers'][1]

        if offer then
            debug(item)
            offer = offer['promotionalOffers'][1]

            local original_price = item['price']['totalPrice']['fmtPrice']['originalPrice']
            local link = 'https://www.epicgames.com/store/en-US/product/' .. item['productSlug']

            local description = '**Start date**\n' .. offer['startDate'] .. '\n' ..
                '**End date**\n' .. offer['endDate'] .. '\n' ..
                '**Price**\n~~' .. original_price .. '~~'

            local embed = {
                title='FREE: ' .. item['title'],
                description=description,
                url=link,
                footer={
                    text='from sn0int kpcyrd/discord-free-epic-games',
                },
            }

            local pic = get_image_tall(item['keyImages'])
            if pic then
                embed['image'] = {
                    url=pic,
                }
            end

            local reinserted = db_activity({
                topic='kpcyrd/discord-free-epic-games:' .. item['productSlug'],
                time=sn0int_time(),
                uniq=item['productSlug'] .. ':' .. offer['startDate'],
                content={},
            })

            if not reinserted then
                notify(discord_webhook, {
                    embeds={embed},
                })
            end
        end
    end
end
