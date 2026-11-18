package org.batocera.minecraft.autolan;

import com.google.gson.JsonObject;
import com.google.gson.JsonParser;
import java.io.Reader;
import java.nio.file.Files;
import java.nio.file.Path;
import net.fabricmc.api.ClientModInitializer;
import net.fabricmc.fabric.api.client.networking.v1.ClientPlayConnectionEvents;
import net.fabricmc.loader.api.FabricLoader;
import net.minecraft.client.Minecraft;
import net.minecraft.client.server.IntegratedServer;
import net.minecraft.server.MinecraftServer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Opens a single-player world to LAN as soon as the player joins it, so the
 * second Split Screen player can connect without anyone using a menu.
 *
 * Only active when config/batocera-autolan.json says {"enabled": true}.
 * batocera-minecraft writes that file: enabled for Split Screen, disabled
 * for Single Player. Online mode is turned off so the offline Player 2
 * account can join.
 */
public final class AutoLan implements ClientModInitializer {
    private static final Logger LOG = LoggerFactory.getLogger("batocera-autolan");
    private static final int DEFAULT_PORT = 25565;

    @Override
    public void onInitializeClient() {
        ClientPlayConnectionEvents.JOIN.register((handler, sender, client) -> client.execute(() -> openToLan(client)));
    }

    private static void openToLan(Minecraft client) {
        IntegratedServer server = client.getSingleplayerServer();
        if (server == null || server.isPublished()) {
            return; // a remote server, or already open
        }
        JsonObject config = readConfig();
        if (config == null || !config.has("enabled") || !config.get("enabled").getAsBoolean()) {
            return;
        }
        int port = config.has("port") ? config.get("port").getAsInt() : DEFAULT_PORT;
        server.setUsesAuthentication(false);
        if (server.publishServer(MinecraftServer.MultiplayerScope.LAN, false, port)) {
            LOG.info("Opened the world to LAN on port {} for Split Screen", port);
        } else {
            LOG.warn("Could not open the world to LAN on port {}", port);
        }
    }

    private static JsonObject readConfig() {
        Path path = FabricLoader.getInstance().getConfigDir().resolve("batocera-autolan.json");
        if (!Files.isRegularFile(path)) {
            return null;
        }
        try (Reader reader = Files.newBufferedReader(path)) {
            return JsonParser.parseReader(reader).getAsJsonObject();
        } catch (Exception e) {
            LOG.warn("Could not read {}: {}", path, e.toString());
            return null;
        }
    }
}
