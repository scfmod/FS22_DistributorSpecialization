# Specialization documentation

## Vehicle

```xml
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<vehicle type="...">
    <distributor>
        ...
    </distributor>
</vehicle>
```

## Distributor

```
vehicle.distributor
```

### Attributes

| Name                         | Type    | Required | Default | Description                                                                                                   |
|------------------------------|---------|----------|---------|---------------------------------------------------------------------------------------------------------------|
| needsToBePoweredOn           | boolean | No       | ```true``` | Vehicle needs to be powered on for machine to process input                                                   |
| needsToBeTurnedOn            | boolean | No       | ```true``` | Vehicle needs to be turned on for machine to process input (requires turnOnVehicle specialization or similar) [^1] |
| canToggleDischargeToGround   | boolean | No       | ```true``` | Whether player can toggle discharge to ground or not                                                          |
| canDischargeToGroundAnywhere | boolean | No       | ```false```|                                                                                                               |
| defaultCanDischargeToGround  | boolean | No       | ```true``` | Set default canDischargeChargeToGround value when vehicle is loaded                                           |

[^1]: If the vehicle doesn't have a turn on function it will disregard this setting.

### Example

```xml
<distributor needsToBeTurnedOn="false" canDischargeToGroundAnywhere="true">
    ...
</distributor>
```


## Processor

```
vehicle.distributor.processor
```

### Attributes

| Name            | Type   | Required | Default | Description                             |
|-----------------|--------|----------|---------|-----------------------------------------|
| processingSpeed | float  | Yes      |         | Processing input speed in liters/second |
| fillUnitIndex   | int    | Yes      |         | Input fillUnit index                    |
| type            | string | No       | ```split```   | Processor type                          |

### Example

```xml
<distributor needsToBeTurnedOn="false" canDischargeToGroundAnywhere="true">
    <processor processingSpeed="400" fillUnitIndex="3">
        ...
    </processor>
</distributor>
```



## Input

```
distributor.processor.fillTypeMappings.input(%)
```

### Attributes

| Name     | Type   | Required | Default | Description         |
|----------|--------|----------|---------|---------------------|
| fillType | string | Yes      |         | Input fillType name |
| name     | string | No       |         | Input name for GUI  |

### Example

```xml
<distributor needsToBeTurnedOn="false" canDischargeToGroundAnywhere="true">
    <processor processingSpeed="400" fillUnitIndex="3">
        <fillTypeMappings>
            <input fillType="RUBBLE" name="Crush the rubble">
                ...
            </input>
            <input fillType="GRAVEL" name="Sort my gravel">
                ...
            </input>
        </fillTypeMappings>
    </processor>
</distributor>
```

## Output

```
distributor.processor.fillTypeMappings.input(%).output(%)
```

### Attributes

| Name          | Type   | Required | Default | Description             |
|---------------|--------|----------|---------|-------------------------|
| fillType      | string | Yes      |         | Output fillType name    |
| fillUnitIndex | int    | Yes      |         | Output fillUnit index   |
| ratio         | float  | Yes      |         | Output ratio from input |
| name          | string | No       |         | Output name for GUI     |


### Example

```xml
<distributor needsToBeTurnedOn="false" canDischargeToGroundAnywhere="true">
    <processor processingSpeed="400" fillUnitIndex="3">
        <fillTypeMappings>
            <input fillType="STONES" name="Crush the rubble">
                <output fillType="GRAVEL" fillUnitIndex="4" ratio="0.8" />
                <output fillType="RUBBLE" fillUnitIndex="5" ratio="0.2" />
            </input>
            <input fillType="GRAVEL" name="Sort my gravel">
                <output fillType="DIRT" fillUnitIndex="4" ratio="0.35" />
                <output fillType="SAND" fillUnitIndex="5" ratio="0.65" />
            </input>
        </fillTypeMappings>
    </processor>
</distributor>
```

## Node

```
vehicle.distributor.processor.nodes.node(%)
```

### Discharge node information

This element provides support for the same child elements as dischargeNode (dischargeable spec):

- info
- raycast
- trigger
- activationTrigger
- distanceObjectChanges
- stateObjectChanges
- nodeActiveObjectChanges
- effects
- dischargeSound
- dischargeStateSound
- animationNodes


For more details on these look at the official documentation files for Vehicle.

### Attributes

| Name                                 | Type      | Required | Default     | Description                  |
|--------------------------------------|-----------|----------|-------------|------------------------------|
| fillUnitIndex                        | int       | Yes      |             | Discharge node fillUnitIndex |
| i3d                                  | nodeIndex | Yes      |             | Discharge node index path    |
| unloadInfoIndex                      | int       | No       | ```1```    |                              |
| effectTurnOffThreshold               | float     | No       | ```0.25``` |                              |
| maxDistance                          | float     | No       | ```10```   | Max discharge distance       |
| soundNode                            | nodeIndex | No       |             | Sound node index path        |
| playSound                            | boolean   | No       | ```true``` | Whether to play sounds       |
| stopDischargeOnEmpty                 | boolean   | No       | ```true``` |                              |
| stopDischargeIfNotPossible           | boolean   | No       | ```true``` |                              |
| canStartDischargeAutomatically       | boolean   | No       | ```true``` |                              |
| canStartGroundDischargeAutomatically | boolean   | No       | ```true``` |                              |

### Example

```xml
<distributor needsToBeTurnedOn="false" canDischargeToGroundAnywhere="true">
    <processor processingSpeed="400" fillUnitIndex="3">
        ...
        <nodes>
            <node fillUnitIndex="4" i3d="frontDischargeNodeIndex">
                ...
            </node>
            <node fillUnitIndex="5" i3d="leftDischargeNodeIndex">
                ...
            </node>
        </nodes>
    </processor>
</distributor>
```

# Vehicle example

```xml
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<vehicle type="...">
    <fillUnit>
        <fillUnitConfigurations>
            <fillUnitConfiguration>
                <fillUnits>
                    <fillUnit capacity="800" unitTextOverride="$l10n_unit_literShort" fillTypes="diesel" showOnHud="false" showInShop="false" />
                    <fillUnit unitTextOverride="$l10n_unit_literShort" showOnHud="false" showInShop="false" fillTypes="def" capacity="39" />

                    <fillUnit capacity="12000" unitTextOverride="$l10n_unit_literShort" fillTypes="" showOnHud="true" showInShop="false" updateMass="false">
                        <exactFillRootNode node="exactFillRootNode" />
                        <autoAimTargetNode node="AimTargetNode" />
                    </fillUnit>

                    <fillUnit capacity="250" unitTextOverride="$l10n_unit_literShort" fillTypes="" showOnHud="true" showInShop="false" updateMass="false" />
                    <fillUnit capacity="250" unitTextOverride="$l10n_unit_literShort" fillTypes="" showOnHud="true" showInShop="false" updateMass="false" />

                </fillUnits>
            </fillUnitConfiguration>
        </fillUnitConfigurations>
    </fillUnit>

    <fillVolume>
        <fillVolumeConfigurations>
            <fillVolumeConfiguration>
                <volumes>
                    <volume node="fillVolumeShape" maxDelta="2.0" maxAllowedHeapAngle="11" fillUnitIndex="3" />
                </volumes>
            </fillVolumeConfiguration>
        </fillVolumeConfigurations>
        <unloadInfos>
            <unloadInfo>
                <node node="unloadInfoFront" width="0.85" length="0.85" />
                <node node="unloadInfoLeft" width="0.55" length="0.55" />
            </unloadInfo>
        </unloadInfos>
    </fillVolume>

    <distributor needsToBeTurnedOn="false" canDischargeToGroundAnywhere="true">
        <processor processingSpeed="400" fillUnitIndex="3">
            <fillTypeMappings>
                <input fillType="STONES" name="Crush the rubble">
                    <output fillType="GRAVEL" fillUnitIndex="4" ratio="0.8" />
                    <output fillType="RUBBLE" fillUnitIndex="5" ratio="0.2" />
                </input>
                <input fillType="GRAVEL" name="Sort my gravel">
                    <output fillType="DIRT" fillUnitIndex="4" ratio="0.35" />
                    <output fillType="SAND" fillUnitIndex="5" ratio="0.65" />
                </input>
            </fillTypeMappings>

            <nodes>
                <node fillUnitIndex="4" unloadInfoIndex="1" i3d="frontDischargeNodeIndex">
                    <activationTrigger node="activationTriggerFront" />
                    <raycast useWorldNegYDirection="true" />
                    <info width="0.55" length="0.85" />
                    <effects>
                        <effectNode effectNode="effectDischargeFront" materialType="unloading" fadeTime="0.2" alignXAxisToWorldY="true" extraDistance="0.2" />
                        <effectNode effectClass="MorphPositionEffect" effectNode="effectDischargeBeltFront" materialType="belt" fadeTime="1" speed="0.25" scrollLength="4" scrollSpeed="1.1" />
                        <effectNode effectNode="effectSmoke1Front" materialType="unloadingSmoke" fadeTime="0" />
                    </effects>
                    <dischargeStateSound template="augerBelt" pitchScale="0.7" volumeScale="1.4" fadeIn="0.2" fadeOut="1" innerRadius="1.0" outerRadius="40.0" linkNode="leftDischargeNodeIndex" />
                </node>
                <node fillUnitIndex="5" unloadInfoIndex="2" i3d="leftDischargeNodeIndex">
                    <activationTrigger node="activationTriggerLeft" />
                    <raycast useWorldNegYDirection="true" />
                    <info width="0.55" length="0.55" />
                    <effects>
                        <effectNode effectNode="effectDischargeLeft" materialType="unloading" fadeTime="0.2" alignXAxisToWorldY="true" extraDistance="0.2" />
                        <effectNode effectClass="MorphPositionEffect" effectNode="effectDischargeBeltLeft" materialType="belt" fadeTime="1" speed="0.25" scrollLength="4" scrollSpeed="1.1" />
                        <effectNode effectNode="effectSmoke1Left" materialType="unloadingSmoke" fadeTime="0" />
                    </effects>
                    <dischargeStateSound template="augerBelt" pitchScale="0.7" volumeScale="1.4" fadeIn="0.2" fadeOut="1" innerRadius="1.0" outerRadius="40.0" linkNode="dischargeNodeLeft" />
                </node>
            </nodes>
        </processor>
    </distributor>
</vehicle>
```