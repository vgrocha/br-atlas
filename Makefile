# Source:
# Institudo Brasileiro de Geologia e Estatistica
# http://mapas.ibge.gov.br/

# -- Configurations

# TopoJSON configurations
TOPOJSON = node --max_old_space_size=8192 node_modules/.bin/topojson -q 1e6

# All Brazilian states
STATES = \
	ac al am ap ba ce df es go ma \
	mg ms mt pa pb pe pi pr rj rn \
	ro rr rs sc se sp to

all: \
	node_modules \
	$(addprefix topo/,$(addsuffix -state.json,$(STATES))) \
	$(addprefix topo/,$(addsuffix -counties.json,$(STATES))) \
	chmod +x scripts/merge.py

# Install dependencies
node_modules:
	npm install

# .SECONDARY with no dependencies marks all file targets mentioned in the makefile as secondary.
.SECONDARY:

# -- Downloading and extracting IBGE files

# Downloads the zip files
# ftp://geoftp.ibge.gov.br/malhas_digitais/municipio_2010/
zip/%.zip:
	mkdir -p $(dir $@)
	curl 'ftp://geoftp.ibge.gov.br/malhas_digitais/municipio_2010/$(notdir $@)' -o $@.download
	mv $@.download $@

# Extracts the files
tmp/%/: zip/%.zip
	rm -rf $(basename $@)
	mkdir -p $(dir $@)
	unzip -d tmp $<

# -- Generate ESRI Shapefile files

# IBGE encodes its data using SIRGAS2000 and the original shapefile
# available for download is not supported by ogr2ogr.
# So I use the .dbf file to generate a ESRI Shapefile which is
# compatible with ogr2ogr.
shp/%/counties.shp: tmp/%/
	mkdir -p $(dir $@)
	ogr2ogr -f 'ESRI Shapefile' $@ tmp/$*/*MUE250GC_SIR.dbf
	touch $@

shp/%/state.shp: tmp/%/
	mkdir -p $(dir $@)
	ogr2ogr -f 'ESRI Shapefile' $@ tmp/$*/*UFE250GC_SIR.dbf
	touch $@

# -- Generate GeoJSON files

geo/%-counties.json: tmp/%/
	mkdir -p $(dir $@)
	ogr2ogr -f GeoJSON $@ tmp/$*/*MUE250GC_SIR.dbf
	iconv -f ISO-8859-1 -t UTF-8 $@ > $@.utf8
	mv $@.utf8 $@
	touch $@

geo/%-state.json: tmp/%/
	mkdir -p $(dir $@)
	ogr2ogr -f GeoJSON $@ tmp/$*/*UFE250GC_SIR.dbf
	iconv -f ISO-8859-1 -t UTF-8 $@ > $@.utf8
	mv $@.utf8 $@
	touch $@

# -- Generating TopoJSON files

# For individual counties
topo/%-counties.json: geo/%-counties.json
	mkdir -p $(dir $@)
	$(TOPOJSON) --id-property=CD_GEOCODM -p name=NM_MUNICIP -o $@ counties=$^
	touch $@

# For individual states:
topo/%-state.json: geo/%-state.json
	mkdir -p $(dir $@)
	$(TOPOJSON) --id-property=CD_GEOCODU -p name=NM_ESTADO -p region=NM_REGIAO -o $@ state=$^
	touch $@

# For Brazil with counties
topo/br-counties.json: $(addprefix geo/,$(addsuffix -counties.json,$(STATES)))
	mkdir -p $(dir $@)
	$(TOPOJSON) --id-property=CD_GEOCODM -p name=NM_MUNICIP -o $@ -- $^
	./scripts/merge.py $@ > $@.merged
	mv $@.merged $@

# For Brasil with states
topo/br-states.json: $(addprefix geo/,$(addsuffix -state.json,$(STATES)))
	mkdir -p $(dir $@)
	$(TOPOJSON) --id-property=CD_GEOCODU -p name=NM_ESTADO -p region=NM_REGIAO -o $@ -- $^
	./scripts/merge.py $@ > $@.merged
	mv $@.merged $@

# -- Clean

# Clean temporary files
clean-tmp:
	rm -rf tmp

# Clean extra files
clean-extra:
	rm -rf zip
	rm -rf tmp

# Clean result files
clean-result:
	rm -rf shp
	rm -rf geo
	rm -rf topo

# Clean everything
clean: clean-tmp clean-result clean-extra